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
    layer.contentsGravity = .resizeAspect
    layer.backgroundColor = UIColor.black.cgColor
    return layer
  }()

  internal lazy var context = CIContext()

  @objc(sharedInstance)
  public static let shared = HSEffectManager()

  private var model: HSSegmentationModel?
  
  private lazy var modelDepthInputPixelBufferPool: CVPixelBufferPool? = {
    guard let size = model?.sizeOf(input: .depthImage) else {
      return nil
    }
    return createCVPixelBufferPool(
      size: size, pixelFormatType: kCVPixelFormatType_OneComponent8
    )
  }()

  private lazy var modelCameraInputPixelBufferPool: CVPixelBufferPool? = {
    guard let size = model?.sizeOf(input: .cameraImage) else {
      return nil
    }
    return createCVPixelBufferPool(
      size: size, pixelFormatType: kCVPixelFormatType_OneComponent8
    )
  }()
  
  private lazy var modelOutputPixelBufferPool: CVPixelBufferPool? = {
    guard let size = model?.sizeOf(output: .segmentationImage) else {
      return nil
    }
    return createCVPixelBufferPool(
      size: size, pixelFormatType: kCVPixelFormatType_OneComponent8
    )
  }()

  private lazy var backgroundImagePixelBufferPool: CVPixelBufferPool? = {
    guard let size = model?.sizeOf(output: .segmentationImage) else {
      return nil
    }
    return createCVPixelBufferPool(
      size: size, pixelFormatType: kCVPixelFormatType_32BGRA
    )
  }()

  private lazy var cameraCVPixelBufferPool: CVPixelBufferPool? = {
    guard let resolution = HSCameraManager.shared.videoResolution else {
      return nil
    }
    return createCVPixelBufferPool(
      size: resolution, pixelFormatType: kCVPixelFormatType_OneComponent8
    )
  }()

  private lazy var rawDepthCVPixelBufferPool: CVPixelBufferPool? = {
    guard let resolution = HSCameraManager.shared.depthResolution else {
      return nil
    }
    return createCVPixelBufferPool(
      size: resolution, pixelFormatType: kCVPixelFormatType_OneComponent8
    )
  }()
  
  private lazy var displayLink: CADisplayLink = {
    let displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLinkUpdate))
    displayLink.preferredFramesPerSecond = 24
    return displayLink
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
        self.model = model
        completionHandler(.success)
      case .err:
        completionHandler(.failedToLoadModel)
      }
    }
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
//          let maskCIImage = CIImage(cgImage: maskCGImage)
//            .applyingFilter("CIEdgePreserveUpsampleFilter", parameters: [
//              "inputSmallImage": CIImage(cgImage: maskCGImage)
//            ])
//            .applyingFilter("CIColorControls", parameters: [
//              "inputContrast": 2
//            ])
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
      let cameraCVPixelBufferPool = cameraCVPixelBufferPool,
      let colorPixelBuffer = HSPixelBuffer(sampleBuffer: sampleBuffer)
    else {
      return nil
    }
    guard let grayscalePixelBuffer = convertBGRAPixelBufferToGrayscale(
      pixelBuffer: colorPixelBuffer, pixelBufferPool: cameraCVPixelBufferPool
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
      let modelDepthInputPixelBufferPool = modelDepthInputPixelBufferPool,
      let rawDepthCVPixelBufferPool = rawDepthCVPixelBufferPool
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
