import AVFoundation
import CoreGraphics
import HSCameraUtils
import UIKit
import MetalKit

@available(iOS 11.0, *)
@objc
class HSEffectManager: NSObject {
  private var queue = DispatchQueue(label: "com.jonbrennecke.HSEffectManager.queue")
  private var videoResolution: Size<Int> = Size<Int>(width: 480, height: 640)
  private var depthResolution: Size<Int> = Size<Int>(width: 480, height: 640)
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
  private lazy var outputPixelBufferPool: CVPixelBufferPool? = {
    createCVPixelBufferPool(
      size: HSCameraManager.shared.videoResolution ?? videoResolution,
      pixelFormatType: HSCameraManager.shared.videoPixelFormat
    )
  }()

  private lazy var displayLink: CADisplayLink = {
    let displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLinkUpdate))
    displayLink.preferredFramesPerSecond = preferredFramesPerSecond
    return displayLink
  }()

  @objc(sharedInstance)
  public static let shared = HSEffectManager()

  @objc
  public var depthData: AVDepthData?

  @objc
  public var videoSampleBuffer: CMSampleBuffer?

  private override init() {
    super.init()
    HSCameraManager.shared.resolutionDelegate = self
  }

  @objc
  private func handleDisplayLinkUpdate(displayLink: CADisplayLink) {
    guard let depthData = depthData, let videoSampleBuffer = videoSampleBuffer else {
      return
    }
    let actualFramesPerSecond = 1 / (displayLink.targetTimestamp - displayLink.timestamp)
    print("Frames per second: \(actualFramesPerSecond)")
    queue.async { [weak self] in
      self?.applyEffects(with: depthData, videoSampleBuffer: videoSampleBuffer)
    }
  }

  private func createOutputPixelBuffer() -> CVPixelBuffer? {
    guard let pool = outputPixelBufferPool else {
      return nil
    }
    return createPixelBuffer(with: pool)
  }

  private func applyEffects(with depthData: AVDepthData, videoSampleBuffer: CMSampleBuffer) {
    let startTime = CFAbsoluteTimeGetCurrent()
    guard let videoPixelBuffer = HSPixelBuffer(sampleBuffer: videoSampleBuffer) else {
      return
    }
    let depthPixelBuffer = HSPixelBuffer(depthData: depthData)
    guard
      let image = depthBlurEffect.makeEffectImage(
        previewMode: .depth,
        depthPixelBuffer: depthPixelBuffer,
        videoPixelBuffer: videoPixelBuffer,
        aperture: HSCameraManager.shared.aperture
      )
    else {
      return
    }
    if let commandBuffer = commandQueue.makeCommandBuffer(), let drawable = effectView.currentDrawable {
      let outputImage = flipImageHorizontally(image: image)
      context.render(
        outputImage,
        to: drawable.texture,
        commandBuffer: commandBuffer,
        bounds: outputImage.extent,
        colorSpace: colorSpace
      )
      commandBuffer.present(drawable)
      commandBuffer.commit()
    }
    let totalTime = CFAbsoluteTimeGetCurrent() - startTime
    print("Render time: \(totalTime)")
  }

  @objc(start:)
  public func start(_ completionHandler: @escaping () -> Void) {
    displayLink.add(to: .main, forMode: .default)
    completionHandler()
  }
}

extension HSEffectManager: HSCameraManagerResolutionDelegate {
  func cameraManagerDidUpdate(videoResolution: Size<Int>, depthResolution: Size<Int>) {
    self.videoResolution = videoResolution
    self.depthResolution = depthResolution
  }
}

fileprivate func flipImageHorizontally(image: CIImage) -> CIImage {
  let transform = image.orientationTransform(for: .upMirrored)
  return image.transformed(by: transform)
}
