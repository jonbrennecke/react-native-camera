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

  @objc(sharedInstance)
  public static let shared = HSEffectManager()

  private static let rawDepthImageSize = Size<Int>(width: 360, height: 640) // TODO: variable depends on device depth resolution
  private static let depthImageSize = Size<Int>(width: 1080, height: 1920)
  private static let cameraImageSize = Size<Int>(width: 1080, height: 1920)
  private static let outputImageSize = Size<Int>(width: 1080, height: 1920)

  private var segmentation: HSSegmentation?

  private lazy var displayLink: CADisplayLink = {
    let displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLinkUpdate))
    displayLink.preferredFramesPerSecond = 24
    return displayLink
  }()
  
  // TODO: same as cameraCVPixelBufferPool
  private lazy var rawCameraCVPixelBufferPool: CVPixelBufferPool = {
    let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey: 1] as CFDictionary
    let bufferAttributes = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
      kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_OneComponent8,
      kCVPixelBufferWidthKey: HSEffectManager.cameraImageSize.width,
      kCVPixelBufferHeightKey: HSEffectManager.cameraImageSize.height,
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

  private lazy var depthCVPixelBufferPool: CVPixelBufferPool = {
    let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey: 1] as CFDictionary
    let bufferAttributes = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
      kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_OneComponent8,
      kCVPixelBufferWidthKey: HSEffectManager.depthImageSize.width,
      kCVPixelBufferHeightKey: HSEffectManager.depthImageSize.height,
    ] as [String: Any] as CFDictionary
    var pool: CVPixelBufferPool!
    CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes, bufferAttributes, &pool)
    return pool
  }()

  private lazy var cameraCVPixelBufferPool: CVPixelBufferPool = {
    let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey: 1] as CFDictionary
    let bufferAttributes = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
      kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_OneComponent8,
      kCVPixelBufferWidthKey: HSEffectManager.cameraImageSize.width,
      kCVPixelBufferHeightKey: HSEffectManager.cameraImageSize.height,
    ] as [String: Any] as CFDictionary
    var pool: CVPixelBufferPool!
    CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes, bufferAttributes, &pool)
    return pool
  }()

  private lazy var outputCVPixelBufferPool: CVPixelBufferPool = {
    let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey: 1] as CFDictionary
    let bufferAttributes = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
      kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_OneComponent8,
      kCVPixelBufferWidthKey: HSEffectManager.outputImageSize.width,
      kCVPixelBufferHeightKey: HSEffectManager.outputImageSize.height,
    ] as [String: Any] as CFDictionary
    var pool: CVPixelBufferPool!
    CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes, bufferAttributes, &pool)
    return pool
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
        self.segmentation = HSSegmentation(model: model)
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
      // TODO: handle error in javascript
      fatalError(error.localizedDescription)
    }
  }

  private func applyEffectsOrThrow(with depthData: AVDepthData, videoSampleBuffer: CMSampleBuffer) throws {
    guard
      let segmentation = segmentation,
      let cameraBuffer = preprocess(sampleBuffer: videoSampleBuffer),
      let depthBuffer = preprocess(depthData: depthData)
    else {
      return
    }
    if let segmentedPixelBuffer = try segmentation.runSegmentation(
      colorBuffer: cameraBuffer,
      depthBuffer: depthBuffer,
      pixelBufferPool: outputCVPixelBufferPool
    ) {
      let imageBuffer = HSImageBuffer(pixelBuffer: segmentedPixelBuffer)
      if let image = imageBuffer.makeImage() {
        DispatchQueue.main.async {
          self.effectLayer.contents = image
        }
      }
    }
  }

  private func preprocess(sampleBuffer: CMSampleBuffer) -> HSPixelBuffer? {
    guard let colorPixelBuffer = HSPixelBuffer(sampleBuffer: sampleBuffer) else {
      return nil
    }
    guard let grayscalePixelBuffer = convertBGRAPixelBufferToGrayscale(
      pixelBuffer: colorPixelBuffer, pixelBufferPool: cameraCVPixelBufferPool
    ) else {
      return nil
    }
    let imageBuffer = HSImageBuffer(pixelBuffer: grayscalePixelBuffer)
    let x = imageBuffer.resize(
      to: HSEffectManager.cameraImageSize,
      pixelBufferPool: cameraCVPixelBufferPool
    )?.pixelBuffer
    return x
  }

  private func preprocess(depthData: AVDepthData) -> HSPixelBuffer? {
    let depthData = convertToDepthFloat32(depthData)
    let buffer = HSPixelBuffer(depthData: depthData)
    let iterator: HSPixelBufferIterator<Float32> = buffer.makeIterator()
    let bounds = iterator.bounds()
    // convert from depthFloat32 to UInt8
    guard let mappedIterator = map(
      iterator,
      pixelFormatType: kCVPixelFormatType_OneComponent8,
      pixelBufferPool: rawDepthCVPixelBufferPool,
      transform: { value -> UInt8 in
        let normalized = normalize(value, min: bounds.lowerBound, max: bounds.upperBound)
        let scaled = normalized * 255
        let pixel = clamp(scaled, min: 0, max: 255)
        return UInt8(exactly: pixel.rounded()) ?? 0
      }
    ) else {
      return nil
    }
    let imageBuffer = HSImageBuffer(pixelBuffer: mappedIterator.pixelBuffer)
    return imageBuffer.resize(
      to: HSEffectManager.depthImageSize,
      pixelBufferPool: depthCVPixelBufferPool,
      isGrayscale: true
    )?.pixelBuffer
  }
}

fileprivate func convertToDepthFloat32(_ depthData: AVDepthData) -> AVDepthData {
  if depthData.depthDataType != kCVPixelFormatType_DepthFloat32 {
    return depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
  }
  return depthData
}
