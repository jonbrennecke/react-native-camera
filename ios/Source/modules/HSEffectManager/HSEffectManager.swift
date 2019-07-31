import AVFoundation
import CoreGraphics
import HSCameraUtils
import UIKit

@available(iOS 11.0, *)
@objc
class HSEffectManager: NSObject {
  private let outputPixelBufferSize = Size<Int>(width: 480, height: 640)
  private lazy var outputPixelBufferPool: CVPixelBufferPool? = {
    createCVPixelBufferPool(
      size: outputPixelBufferSize,
      pixelFormatType: kCVPixelFormatType_32BGRA
    )
  }()

  private lazy var mtlDevice: MTLDevice! = {
    guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
      fatalError("Failed to create Metal device")
    }
    return mtlDevice
  }()

  private lazy var context = CIContext(mtlDevice: mtlDevice)
  private lazy var depthBlurEffect = HSDepthBlurEffect()

  private lazy var displayLink: CADisplayLink = {
    let displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLinkUpdate))
    displayLink.preferredFramesPerSecond = 30
    return displayLink
  }()

  internal lazy var effectLayer: CALayer = {
    let layer = CALayer()
    layer.contentsGravity = .resizeAspectFill
    layer.backgroundColor = UIColor.black.cgColor
    return layer
  }()

  @objc(sharedInstance)
  public static let shared = HSEffectManager()

  @objc
  public var depthData: AVDepthData?

  @objc
  public var videoSampleBuffer: CMSampleBuffer?

  @objc
  private func handleDisplayLinkUpdate(_: CADisplayLink) {
    guard let depthData = depthData, let videoSampleBuffer = videoSampleBuffer else {
      return
    }
    applyEffects(with: depthData, videoSampleBuffer: videoSampleBuffer)
  }

  private func createOutputPixelBuffer() -> CVPixelBuffer? {
    guard let pool = outputPixelBufferPool else {
      return nil
    }
    return createPixelBuffer(with: pool)
  }

  private func applyEffects(with depthData: AVDepthData, videoSampleBuffer: CMSampleBuffer) {
    guard let videoPixelBuffer = HSPixelBuffer(sampleBuffer: videoSampleBuffer) else {
      return
    }
    let depthPixelBuffer = HSPixelBuffer(depthData: depthData)
    guard
      let ciImage = depthBlurEffect.makeEffectImage(
        depthPixelBuffer: depthPixelBuffer,
        videoPixelBuffer: videoPixelBuffer,
        aperture: HSCameraManager.shared.aperture
      ),
      let pixelBuffer = createOutputPixelBuffer()
    else {
      return
    }
    ciImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
    ciImage.transformed(by: CGAffineTransform(translationX: 0, y: ciImage.extent.size.height))
    context.render(ciImage, to: pixelBuffer)
    let imageBuffer = HSImageBuffer(cvPixelBuffer: pixelBuffer)
    guard let outputImage = imageBuffer.makeCGImage() else {
      return
    }
    DispatchQueue.main.async {
      self.effectLayer.contents = outputImage
    }
  }

  @objc(start:)
  public func start(_ completionHandler: @escaping () -> Void) {
    displayLink.add(to: .main, forMode: .default)
    completionHandler()
  }
}
