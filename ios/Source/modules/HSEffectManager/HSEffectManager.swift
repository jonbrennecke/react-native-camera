import AVFoundation
import CoreGraphics
import HSCameraUtils
import MetalKit
import UIKit

@available(iOS 11.0, *)
@objc
class HSEffectManager: NSObject {
  private let printDebugLog = true
  private let preferredFramesPerSecond = 15

  private lazy var mtlDevice: MTLDevice! = {
    guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
      fatalError("Failed to create Metal device")
    }
    return mtlDevice
  }()

  internal lazy var effectView: MTKView = {
    let view = MTKView(frame: .zero, device: mtlDevice)
    view.device = mtlDevice
    view.framebufferOnly = false
    view.preferredFramesPerSecond = preferredFramesPerSecond
    view.autoResizeDrawable = true
    view.enableSetNeedsDisplay = false
    return view
  }()

  private lazy var commandQueue: MTLCommandQueue! = {
    guard let commandQueue = mtlDevice.makeCommandQueue() else {
      fatalError("Failed to create Metal command queue")
    }
    return commandQueue
  }()

  private lazy var context = CIContext(mtlDevice: mtlDevice, options: [CIContextOption.workingColorSpace: NSNull()])
  private let grayscaleColorSpace = CGColorSpaceCreateDeviceGray()
  private let colorSpace = CGColorSpaceCreateDeviceRGB()
  private lazy var depthBlurEffect = HSDepthBlurEffect()
  private lazy var displayLink: CADisplayLink = {
    let displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLinkUpdate))
    displayLink.preferredFramesPerSecond = preferredFramesPerSecond
    return displayLink
  }()

  @objc
  private func handleDisplayLinkUpdate(displayLink: CADisplayLink) {
    guard let depthData = depthData, let videoSampleBuffer = videoSampleBuffer else {
      return
    }
    if printDebugLog {
      let actualFramesPerSecond = 1 / (displayLink.targetTimestamp - displayLink.timestamp)
      print("[HSEffectManager]: Frames per second: \(actualFramesPerSecond)")
    }
    applyEffects(with: depthData, videoSampleBuffer: videoSampleBuffer)
  }

  private func applyEffects(with depthData: AVDepthData, videoSampleBuffer: CMSampleBuffer) {
    let startTime = CFAbsoluteTimeGetCurrent()
    guard let videoPixelBuffer = HSPixelBuffer(sampleBuffer: videoSampleBuffer) else {
      return
    }
    let isDepth = [kCVPixelFormatType_DepthFloat16, kCVPixelFormatType_DepthFloat32].contains(depthData.depthDataType)
    let disparityData = isDepth ? depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat16) : depthData
    let disparityPixelBuffer = HSPixelBuffer(depthData: disparityData)
    guard
      let image = depthBlurEffect.makeEffectImage(
        previewMode: isDepthPreviewEnabled ? .depth : .portraitBlur,
        qualityMode: .previewQuality,
        disparityPixelBuffer: disparityPixelBuffer,
        videoPixelBuffer: videoPixelBuffer,
        aperture: HSCameraManager.shared.aperture
      )
    else {
      return
    }
    if let commandBuffer = commandQueue.makeCommandBuffer(), let drawable = effectView.currentDrawable {
      let outputImage = imageByFlippingHorizontally(image: image)
      if let resizedImage = imageByResizing(image: outputImage, toFitView: effectView) {
        context.render(
          resizedImage,
          to: drawable.texture,
          commandBuffer: commandBuffer,
          bounds: resizedImage.extent,
          colorSpace: colorSpace
        )
        effectView.drawableSize = effectView.frame.size
      }
      commandBuffer.present(drawable)
      commandBuffer.commit()
    }
    if printDebugLog {
      let totalTime = CFAbsoluteTimeGetCurrent() - startTime
      print("[HSEffectManager]: Render time: \(totalTime)")
    }
  }

  public var isDepthPreviewEnabled = false

  // MARK: - Objective-C interface

  @objc(sharedInstance)
  public static let shared = HSEffectManager()

  @objc
  public var depthData: AVDepthData?

  @objc
  public var videoSampleBuffer: CMSampleBuffer?

  @objc(start:)
  public func start(_ completionHandler: @escaping () -> Void) {
    displayLink.add(to: .main, forMode: .default)
    completionHandler()
  }
}

fileprivate func imageByFlippingHorizontally(image: CIImage) -> CIImage {
  let transform = image.orientationTransform(for: .upMirrored)
  return image.transformed(by: transform)
}

fileprivate func imageByResizing(image: CIImage, toFitView view: UIView) -> CIImage? {
  let aspectRatio = image.extent.width / image.extent.height
  let scaleHeight = (view.frame.height * aspectRatio) / image.extent.width
  let scaleWidth = view.frame.width / image.extent.width
  let scale = (image.extent.height * scaleWidth) < view.frame.height
    ? scaleHeight
    : scaleWidth
  guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
    return nil
  }
  filter.setValue(image, forKey: kCIInputImageKey)
  filter.setValue(scale, forKey: kCIInputScaleKey)
  filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
  return filter.outputImage
}
