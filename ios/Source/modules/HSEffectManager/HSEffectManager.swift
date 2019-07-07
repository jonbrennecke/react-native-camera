import AVFoundation
import CoreGraphics
import HSCameraUtils
import UIKit

@available(iOS 11.0, *)
@objc
class HSEffectManager: NSObject {
  internal lazy var effectLayer: CALayer = {
    let layer = CALayer()
    layer.contentsGravity = .resizeAspectFill
    layer.backgroundColor = UIColor.red.cgColor
    return layer
  }()

  @objc(sharedInstance)
  public static let shared = HSEffectManager()

  private static let depthImageSize = Size<Int>(width: 1080, height: 1920)
  private static let colorImageSize = Size<Int>(width: 1080, height: 1920)

  private var segmentation: HSSegmentation?
  private let context = CIContext()

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

  private lazy var colorCVPixelBufferPool: CVPixelBufferPool = {
    let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey: 1] as CFDictionary
    let bufferAttributes = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
      kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey: HSEffectManager.colorImageSize.width,
      kCVPixelBufferHeightKey: HSEffectManager.colorImageSize.height,
    ] as [String: Any] as CFDictionary
    var pool: CVPixelBufferPool!
    CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes, bufferAttributes, &pool)
    return pool
  }()

  @objc
  public func start() {
    HSSegmentationModelLoader.loadModel { result in
      switch result {
      case let .ok(model):
        self.segmentation = HSSegmentation(model: model)
      case .err:
        fatalError("Failed to load model") // FIXME: add completionHandler callback
      }
    }
  }

  @objc(applyEffectWithDepthData:videoData:error:)
  public func applyEffect(with depthData: AVDepthData, videoSampleBuffer _: CMSampleBuffer) throws {
    guard
//      let segmentation = segmentation,
//      let colorBuffer = preprocess(sampleBuffer: videoSampleBuffer),
      let depthBuffer = preprocess(depthData: depthData)
    else {
      return
    }

//    let imageBuffer = HSImageBuffer(pixelBuffer: colorBuffer)

    let imageBuffer = HSImageBuffer(pixelBuffer: depthBuffer)
    if let cgImage = imageBuffer.makeImage() {
      DispatchQueue.main.async {
        self.effectLayer.contents = cgImage
      }
    }

//      do {
//        if let pixelBuffer = try segmentation.runSegmentation(colorBuffer: colorPixelBuffer, depthBuffer: depthPixelBuffer) {
//          let imageBuffer = HSImageBuffer(pixelBuffer: pixelBuffer)
//          if let image = imageBuffer.makeImage() {
//            DispatchQueue.main.async {
//              print("set layer contents")
//              self.effectLayer.contents = image
//            }
//          }
//        }

//      }
//      catch let error {
//        fatalError(error.localizedDescription)
//      }
  }

  private func preprocess(sampleBuffer: CMSampleBuffer) -> HSPixelBuffer? {
    guard let buffer = HSPixelBuffer(sampleBuffer: sampleBuffer) else {
      return nil
    }
    return resize(
      buffer,
      to: HSEffectManager.colorImageSize,
      pixelBufferPool: colorCVPixelBufferPool
    )
  }

  private func preprocess(depthData: AVDepthData) -> HSPixelBuffer? {
    let depthData = convertToDepthFloat32(depthData)
    let buffer = HSPixelBuffer(depthData: depthData)
    let iterator: HSPixelBufferIterator<Float32> = buffer.makeIterator()
    let bounds = iterator.bounds()
    guard let mappedIterator = map(iterator, to: kCVPixelFormatType_OneComponent8, transform: { value -> UInt8 in
      let normalized = normalize(value, min: bounds.lowerBound, max: bounds.upperBound)
      let scaled = normalized * 255
      let pixel = clamp(scaled, min: 0, max: 255)
      return UInt8(exactly: pixel.rounded()) ?? 0
    }) else {
      return nil
    }
    return resize(
      mappedIterator.pixelBuffer,
      to: HSEffectManager.depthImageSize,
      pixelBufferPool: depthCVPixelBufferPool,
      isGrayscale: true
    )
  }
}

fileprivate func convertToDepthFloat32(_ depthData: AVDepthData) -> AVDepthData {
  if depthData.depthDataType != kCVPixelFormatType_DepthFloat32 {
    return depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
  }
  return depthData
}
