import AVFoundation
import CoreGraphics
import HSCameraUtils
import UIKit

@available(iOS 11.0, *)
@objc
class HSEffectManager: NSObject {
  @objc(HSEffectManagerResult)
  public enum Result: Int {
    case success
    case failedToLoadModel
  }

  internal lazy var effectLayer: CALayer = {
    let layer = CALayer()
    layer.contentsGravity = .resizeAspectFill
    layer.backgroundColor = UIColor.black.cgColor
    return layer
  }()

  internal lazy var context = CIContext()

  @objc(sharedInstance)
  public static let shared = HSEffectManager()

  // TODO: raw input sizes depend on device's camera resolution which may vary
  private static let rawCameraImageSize = Size<Int>(width: 1080, height: 1920)
  private static let rawDepthImageSize = Size<Int>(width: 360, height: 640)

  private var model: HSSegmentationModel?
  private var modelDepthInputPixelBufferPool: CVPixelBufferPool?
  private var modelCameraInputPixelBufferPool: CVPixelBufferPool?
  private var modelOutputPixelBufferPool: CVPixelBufferPool?

  private lazy var backgroundImagePixelBufferPool: CVPixelBufferPool? = {
    guard let size = model?.sizeOf(output: .segmentationImage) else {
      return nil
    }
    return createCVPixelBufferPool(
      size: size, pixelFormatType: kCVPixelFormatType_32BGRA
    )
  }()

  private lazy var displayLink: CADisplayLink = {
    let displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLinkUpdate))
    displayLink.preferredFramesPerSecond = 24
    return displayLink
  }()

  private lazy var rawCameraCVPixelBufferPool: CVPixelBufferPool = {
    let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey: 1] as CFDictionary
    let bufferAttributes = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
      kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_OneComponent8,
      kCVPixelBufferWidthKey: HSEffectManager.rawCameraImageSize.width,
      kCVPixelBufferHeightKey: HSEffectManager.rawCameraImageSize.height,
    ] as [String: Any] as CFDictionary
    var pool: CVPixelBufferPool!
    CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes, bufferAttributes, &pool)
    return pool
  }()

  private lazy var rawDepthCVPixelBufferPool: CVPixelBufferPool = {
    let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey: 1] as CFDictionary
    let bufferAttributes = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
      kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_OneComponent8,
      kCVPixelBufferWidthKey: HSEffectManager.rawDepthImageSize.width,
      kCVPixelBufferHeightKey: HSEffectManager.rawDepthImageSize.height,
    ] as [String: Any] as CFDictionary
    var pool: CVPixelBufferPool!
    CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes, bufferAttributes, &pool)
    return pool
  }()

  private lazy var backgroundBuffer: HSPixelBuffer? = {
    guard
      let size = model?.sizeOf(output: .segmentationImage),
      let pool = backgroundImagePixelBufferPool
    else {
      return nil
    }
    let bufferInfo = HSBufferInfo(pixelFormatType: kCVPixelFormatType_32BGRA)
    var pixels = [HS32BGRAPixelValue](repeating: .red, count: size.width * size.height)
    return createPixelBuffer(data: &pixels, size: size, pool: pool, bufferInfo: bufferInfo)
  }()

  private lazy var backgroundImage: CIImage? = {
    guard
      let backgroundBuffer = backgroundBuffer,
      let backgroundCGImage = HSImageBuffer(pixelBuffer: backgroundBuffer).makeImage()
    else {
      return nil
    }
    return CIImage(cgImage: backgroundCGImage)
  }()

  @objc
  public var depthData: AVDepthData?

  @objc
  public var videoSampleBuffer: CMSampleBuffer?

  @objc(start:)
  public func start(_ completionHandler: @escaping (HSEffectManager.Result) -> Void) {
    loadModel { result in
      self.displayLink.add(to: .main, forMode: .default)
      completionHandler(result)
    }
  }

  private func loadModel(_ completionHandler: @escaping (HSEffectManager.Result) -> Void) {
    HSSegmentationModelLoader.loadModel { result in
      switch result {
      case let .ok(model):
        self.configureModelSettings(with: model)
        completionHandler(.success)
      case .err:
        completionHandler(.failedToLoadModel)
      }
    }
  }

  private func configureModelSettings(with model: HSSegmentationModel) {
    self.model = model

    // configure depth image input size
    guard let depthInputSize = model.sizeOf(input: .depthImage) else {
      fatalError("Could not determine the size of depth input for the CoreML model.")
    }
    modelDepthInputPixelBufferPool = createCVPixelBufferPool(
      size: depthInputSize, pixelFormatType: kCVPixelFormatType_OneComponent8
    )

    // configure camera image input size
    guard let cameraInputSize = model.sizeOf(input: .cameraImage) else {
      fatalError("Could not determine the size of camera input for the CoreML model.")
    }
    modelCameraInputPixelBufferPool = createCVPixelBufferPool(
      size: cameraInputSize, pixelFormatType: kCVPixelFormatType_OneComponent8
    )

    // configure output size
    guard let outputSize = model.sizeOf(output: .segmentationImage) else {
      fatalError("Could not determine the output size for the CoreML model.")
    }
    modelOutputPixelBufferPool = createCVPixelBufferPool(
      size: outputSize, pixelFormatType: kCVPixelFormatType_OneComponent8
    )
  }

  @objc
  private func handleDisplayLinkUpdate(_: CADisplayLink) {
    guard let depthData = depthData, let videoSampleBuffer = videoSampleBuffer else {
      return
    }
    applyEffects(with: depthData, videoSampleBuffer: videoSampleBuffer)
  }

  private func applyEffects(with depthData: AVDepthData, videoSampleBuffer: CMSampleBuffer) {
    do {
      try applyEffectsOrThrow(with: depthData, videoSampleBuffer: videoSampleBuffer)
    } catch {
      // TODO: handle error in javascript by dispatching event
      fatalError(error.localizedDescription)
    }
  }

  private func applyEffectsOrThrow(with depthData: AVDepthData, videoSampleBuffer: CMSampleBuffer) throws {
    guard
      let model = model,
      let cameraBuffer = preprocess(sampleBuffer: videoSampleBuffer),
      let depthBuffer = preprocess(depthData: depthData),
      let modelOutputPixelBufferPool = modelOutputPixelBufferPool
    else {
      return
    }
    if let maskPixelBuffer = try createSegmentationMask(
      model: model,
      colorBuffer: cameraBuffer,
      depthBuffer: depthBuffer,
      pixelBufferPool: modelOutputPixelBufferPool
    ) {
      let maskImageBuffer = HSImageBuffer(pixelBuffer: maskPixelBuffer)
      let cameraImageBuffer = HSImageBuffer(pixelBuffer: cameraBuffer)
      if
        let maskCGImage = maskImageBuffer.makeImage(),
        let cameraCGImage = cameraImageBuffer.makeImage(),
        let backgroundCIImage = backgroundImage {
        DispatchQueue.main.async {
          let cameraCIImage = CIImage(cgImage: cameraCGImage)
          let maskCIImage = CIImage(cgImage: maskCGImage)
          let composedImage = cameraCIImage
            .applyingFilter("CIBlendWithMask", parameters: [
              "inputMaskImage": maskCIImage,
              "inputBackgroundImage": backgroundCIImage,
            ])
          let composedCGImage = self.context.createCGImage(composedImage, from: composedImage.extent)
          self.effectLayer.contents = composedCGImage
        }
      }
    }
  }

  private func preprocess(sampleBuffer: CMSampleBuffer) -> HSPixelBuffer? {
    guard
      let modelCameraInputSize = model?.sizeOf(input: .cameraImage),
      let modelCameraInputPixelBufferPool = modelCameraInputPixelBufferPool,
      let colorPixelBuffer = HSPixelBuffer(sampleBuffer: sampleBuffer)
    else {
      return nil
    }
    guard let grayscalePixelBuffer = convertBGRAPixelBufferToGrayscale(
      pixelBuffer: colorPixelBuffer, pixelBufferPool: rawCameraCVPixelBufferPool
    ) else {
      return nil
    }
    let imageBuffer = HSImageBuffer(pixelBuffer: grayscalePixelBuffer)
    return imageBuffer.resize(
      to: modelCameraInputSize,
      pixelBufferPool: modelCameraInputPixelBufferPool,
      isGrayscale: true
    )?.pixelBuffer
  }

  private func preprocess(depthData: AVDepthData) -> HSPixelBuffer? {
    guard
      let modelDepthInputSize = model?.sizeOf(input: .depthImage),
      let modelDepthInputPixelBufferPool = modelDepthInputPixelBufferPool
    else {
      return nil
    }
    let buffer = HSPixelBuffer(depthData: depthData)
    let iterator: HSPixelBufferIterator<Float> = buffer.makeIterator()
    let bounds = iterator.bounds()
    guard let depthPixelBuffer = convertDisparityFloat32PixelBufferToUInt8(
      pixelBuffer: buffer, pixelBufferPool: rawDepthCVPixelBufferPool, bounds: bounds
    ) else {
      return nil
    }
    let imageBuffer = HSImageBuffer(pixelBuffer: depthPixelBuffer)
    return imageBuffer.resize(
      to: modelDepthInputSize,
      pixelBufferPool: modelDepthInputPixelBufferPool,
      isGrayscale: true
    )?.pixelBuffer
  }
}
