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
    view.drawableSize = view.frame.size
    return view
  }()

  private lazy var commandQueue: MTLCommandQueue! = {
    guard let commandQueue = mtlDevice.makeCommandQueue(maxCommandBufferCount: 10) else {
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
  
  public var previewMode: HSEffectPreviewMode = .portraitMode
  public var resizeMode: HSResizeMode = .scaleAspectWidth

  @objc
  private func handleDisplayLinkUpdate(displayLink: CADisplayLink) {
    autoreleasepool {
      guard let depthData = depthData, let videoSampleBuffer = videoSampleBuffer else {
        return
      }
      if printDebugLog {
        let actualFramesPerSecond = 1 / (displayLink.targetTimestamp - displayLink.timestamp)
        print("[HSEffectManager]: Frames per second: \(actualFramesPerSecond)")
      }
      applyEffects(with: depthData, videoSampleBuffer: videoSampleBuffer)
    }
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
        previewMode: previewMode == .depth ? .depth : .portraitBlur,
        qualityMode: .previewQuality,
        disparityPixelBuffer: disparityPixelBuffer,
        videoPixelBuffer: videoPixelBuffer,
        aperture: HSCameraManager.shared.aperture
      )
    else {
      return
    }
    if let commandBuffer = commandQueue.makeCommandBuffer(), let drawable = effectView.currentDrawable {
      if let resizedImage = resize(image: image, in: effectView.frame.size, resizeMode: resizeMode) {
        context.render(
          resizedImage,
          to: drawable.texture,
          commandBuffer: commandBuffer,
          bounds: resizedImage.extent,
          colorSpace: colorSpace
        )
      }
      commandBuffer.present(drawable)
      commandBuffer.commit()
    }
    if printDebugLog {
      let totalTime = CFAbsoluteTimeGetCurrent() - startTime
      print("[HSEffectManager]: Render time: \(totalTime)")
    }
  }

  public func startDisplayLink() {
    HSCameraManager.shared.depthDelegate = self
    displayLink.add(to: .main, forMode: .default)
  }

  public func stopDisplayLink() {
    HSCameraManager.shared.depthDelegate = nil
    displayLink.remove(from: .main, forMode: .default)
  }

  // MARK: - Objective-C interface

  @objc(sharedInstance)
  public static let shared = HSEffectManager()

  @objc
  public var depthData: AVDepthData?

  @objc
  public var videoSampleBuffer: CMSampleBuffer?
}

extension HSEffectManager: HSCameraManagerDepthDataDelegate {
  func cameraManagerDidOutput(depthData: AVDepthData) {
    self.depthData = depthData
  }

  func cameraManagerDidOutput(videoSampleBuffer: CMSampleBuffer) {
    self.videoSampleBuffer = videoSampleBuffer
  }
}

fileprivate func resize(image: CIImage, in size: CGSize, resizeMode: HSResizeMode) -> CIImage? {
  guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
    return nil
  }
  filter.setValue(image, forKey: kCIInputImageKey)
  filter.setValue(calculateScale(from: image.extent.size, in: size, resizeMode: resizeMode), forKey: kCIInputScaleKey)
  filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
  return filter.outputImage
}

fileprivate func calculateScale(from imageSize: CGSize, in size: CGSize, resizeMode: HSResizeMode) -> CGFloat {
  let aspectRatio = imageSize.width / imageSize.height
  let scaleHeight = (size.height * aspectRatio) / size.width
  let scaleWidth = size.width / imageSize.width
  switch resizeMode {
  case .scaleAspectFill:
    return (imageSize.height * scaleWidth) < size.height
      ? scaleHeight
      : scaleWidth
  case .scaleAspectWidth:
    return scaleWidth
  case .scaleAspectHeight:
    return scaleHeight
  }
}
