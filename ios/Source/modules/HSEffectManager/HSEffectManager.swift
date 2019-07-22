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

  private var model: HSSegmentationModel? // TODO: remove model from HSEffectManager
  private var portraitMaskFactory: HSPortraitMaskFactory?

  // TODO: remove model from HSEffectManager
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
    guard let backgroundBuffer = backgroundBuffer else {
      return nil
    }
    return HSImageBuffer(pixelBuffer: backgroundBuffer).makeCIImage()
  }()

  internal lazy var effectLayer: CALayer = {
    let layer = CALayer()
    layer.contentsGravity = .resizeAspect
    layer.backgroundColor = UIColor.black.cgColor
    return layer
  }()

  internal lazy var context = CIContext()

  @objc(sharedInstance)
  public static let shared = HSEffectManager()

  @objc
  public var depthData: AVDepthData?

  @objc
  public var videoSampleBuffer: CMSampleBuffer?

  private func loadModel(_ completionHandler: @escaping (HSEffectManager.Result) -> Void) {
    HSSegmentationModelLoader.loadModel { result in
      switch result {
      case let .ok(model):
        self.model = model
        self.portraitMaskFactory = HSPortraitMaskFactory(model: model)
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
    guard
      let portraitMask = portraitMaskFactory?.makePortraitMask(
        depthData: depthData, videoSampleBuffer: videoSampleBuffer
      ),
      let backgroundImage = backgroundImage,
      let composedImage = portraitMask.imageByApplyingMask(toBackground: backgroundImage)
    else {
      return
    }
    let composedCGImage = context.createCGImage(composedImage, from: composedImage.extent)
    DispatchQueue.main.async {
      self.effectLayer.contents = composedCGImage
    }
  }

  @objc(start:)
  public func start(_ completionHandler: @escaping (HSEffectManager.Result) -> Void) {
    loadModel { result in
      self.displayLink.add(to: .main, forMode: .default)
      completionHandler(result)
    }
  }
}
