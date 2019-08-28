import AVFoundation
import HSCameraUtils
import MetalKit
import UIKit

class HSMetalEffectView: MTKView, HSDebuggable {
  private lazy var commandQueue: MTLCommandQueue! = {
    let maxCommandBufferCount = 10
    guard let commandQueue = device?.makeCommandQueue(maxCommandBufferCount: maxCommandBufferCount) else {
      fatalError("Failed to create Metal command queue")
    }
    return commandQueue
  }()

  private lazy var context: CIContext! = {
    guard let device = device else {
      fatalError("Failed to get Metal device")
    }
    return CIContext(mtlDevice: device, options: [
      .workingColorSpace: NSNull(),
      .highQualityDownsample: false,
    ])
  }()

  override var isPaused: Bool {
    didSet {
      effectSession?.isPaused = isPaused
    }
  }

  private var imageExtent: CGRect = .zero
  private let colorSpace = CGColorSpaceCreateDeviceRGB()
  private let renderSemaphore = DispatchSemaphore(value: 1)
  private weak var effectSession: HSEffectSession?

  internal var isDebugLogEnabled = false

  public var resizeMode: HSResizeMode = .scaleAspectWidth
  public var blurAperture: Float = 2.4

  public init(effectSession: HSEffectSession) {
    guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
      fatalError("Failed to create Metal device")
    }
    super.init(frame: .zero, device: mtlDevice)
    self.effectSession = effectSession
    framebufferOnly = false
    preferredFramesPerSecond = 24
    colorPixelFormat = .bgra8Unorm
    autoResizeDrawable = true
    enableSetNeedsDisplay = false
    drawableSize = frame.size
    contentScaleFactor = UIScreen.main.scale
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
  }

  required init(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    renderSemaphore.signal()
  }

  override func draw(_ rect: CGRect) {
    super.draw(rect)
    let startTime = CFAbsoluteTimeGetCurrent()
    defer {
      let executionTime = CFAbsoluteTimeGetCurrent() - startTime
      if isDebugLogEnabled {
        print("\(debugPrefix(describing: #selector(draw(_:)))) \(executionTime)")
      }
    }
    render()
  }

  private func render() {
    guard let image = effectSession?.makeEffectImage(
      blurAperture: blurAperture,
      outputSize: frame.size.integerSize(),
//      CGSize(width: frame.width * 0.5, height: frame.height * 0.5),
      resizeMode: resizeMode
    ) else {
      return
    }
//    let scale = scaleForResizing(image.extent.size, to: frame.size, resizeMode: resizeMode)
//    let scaledImage = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let scaledImage = image
    imageExtent = scaledImage.extent
    autoreleasepool {
      present(image: scaledImage)
    }
  }

  private func present(image: CIImage) {
    _ = renderSemaphore.wait(timeout: DispatchTime.distantFuture)
    if let commandBuffer = commandQueue.makeCommandBuffer() {
      defer { commandBuffer.commit() }
      if let drawable = currentDrawable {
        let renderDestination = CIRenderDestination(
          width: Int(drawableSize.width),
          height: Int(drawableSize.height),
          pixelFormat: colorPixelFormat,
          commandBuffer: commandBuffer
        ) { () -> MTLTexture in
          return drawable.texture
        }
        _ = try? context.startTask(toClear: renderDestination)
        _ = try? context.startTask(toRender: image, to: renderDestination)
        commandBuffer.addScheduledHandler { [weak self] _ in
          self?.renderSemaphore.signal()
        }
        commandBuffer.present(drawable, afterMinimumDuration: 1 / Double(preferredFramesPerSecond))
      }
    }
  }

  public func captureDevicePointConverted(fromLayerPoint layerPoint: CGPoint) -> CGPoint {
    if let videoSize = HSCameraManager.shared.videoResolution {
      let scale = scaleForResizing(imageExtent.size, to: frame.size, resizeMode: resizeMode)
      return CGPoint(
        x: (layerPoint.x / scale) / CGFloat(videoSize.width),
        y: (layerPoint.y / scale) / CGFloat(videoSize.height)
      )
    }
    return .zero
  }
}
