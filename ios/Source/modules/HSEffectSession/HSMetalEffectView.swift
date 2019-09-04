import AVFoundation
import HSCameraUtils
import MetalKit
import UIKit

// the max number of concurrent drawables supported by CoreAnimation
fileprivate let maxSimultaneousFrames: Int = 3

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
  private let renderSemaphore = DispatchSemaphore(value: maxSimultaneousFrames)
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
    clearsContextBeforeDrawing = true
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
    _ = renderSemaphore.wait(timeout: DispatchTime.distantFuture)
    autoreleasepool {
      guard let image = effectSession?.makeEffectImage(
        blurAperture: blurAperture,
        size: frame.size,
        resizeMode: resizeMode
      ) else {
        renderSemaphore.signal()
        return
      }
      imageExtent = image.extent
      present(image: image)
    }
  }

  private func present(image: CIImage) {
    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
      renderSemaphore.signal()
      return
    }
    defer { commandBuffer.commit() }
    guard let drawable = currentDrawable else {
      renderSemaphore.signal()
      return
    }
    context.render(
      image,
      to: drawable.texture,
      commandBuffer: commandBuffer,
      bounds: image.extent,
      colorSpace: colorSpace
    )
    commandBuffer.addCompletedHandler { [weak self] _ in
      self?.renderSemaphore.signal()
    }
    commandBuffer.present(drawable, afterMinimumDuration: 1 / Double(preferredFramesPerSecond))
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
