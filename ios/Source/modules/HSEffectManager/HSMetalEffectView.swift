import AVFoundation
import HSCameraUtils
import MetalKit
import UIKit

class HSMetalEffectView: MTKView, HSDebuggable {
  private lazy var commandQueue: MTLCommandQueue! = {
    let maxCommandBufferCount = 1
    guard let commandQueue = device?.makeCommandQueue() else {
      fatalError("Failed to create Metal command queue")
    }
    return commandQueue
  }()

  private lazy var context: CIContext! = {
    guard let device = device else {
      fatalError("Failed to get Metal device")
    }
    return CIContext(mtlDevice: device, options: [
      CIContextOption.workingColorSpace: NSNull(),
    ])
  }()

  private var imageExtent: CGRect = .zero
  private let colorSpace = CGColorSpaceCreateDeviceRGB()
  private let renderSemaphore = DispatchSemaphore(value: 1)
  private weak var effectManager: HSEffectManager?

  internal var isDebugLogEnabled = true

  public var resizeMode: HSResizeMode = .scaleAspectWidth
  public var blurAperture: Float = 0

  private lazy var lanczosScaleTransformFilter: CIFilter? = {
    guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
      return nil
    }
    filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
    return filter
  }()

  public init(effectManager: HSEffectManager) {
    guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
      fatalError("Failed to create Metal device")
    }
    super.init(frame: .zero, device: mtlDevice)
    self.effectManager = effectManager
    framebufferOnly = false
    preferredFramesPerSecond = 30
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
//    TODO:
//    let startTime = CFAbsoluteTimeGetCurrent()
//    defer {
//      let executionTime = CFAbsoluteTimeGetCurrent() - startTime
//      if isDebugLogEnabled {
//        print("\(debugPrefix(describing: #selector(draw(_:)))) \(executionTime)")
//      }
//    }
    render()
  }

  private func render() {
    _ = renderSemaphore.wait(timeout: DispatchTime.distantFuture)
    guard let image = effectManager?.makeEffectImage(blurAperture: blurAperture) else {
      renderSemaphore.signal()
      return
    }

    imageExtent = image.extent
    autoreleasepool {
      present(image: image, resizeMode: resizeMode)
    }
  }

  private func present(image: CIImage, resizeMode: HSResizeMode) {
    if let commandBuffer = commandQueue.makeCommandBuffer() {
      defer { commandBuffer.commit() }
      guard let resizedImage = resize(image: image, in: frame.size, resizeMode: resizeMode) else {
        renderSemaphore.signal()
        return
      }
      if let drawable = (layer as? CAMetalLayer)?.nextDrawable() {
        let renderDestination = CIRenderDestination(
          width: Int(drawableSize.width),
          height: Int(drawableSize.height),
          pixelFormat: colorPixelFormat,
          commandBuffer: commandBuffer
        ) { () -> MTLTexture in
          return drawable.texture
        }
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try? context.startTask(toClear: renderDestination)
        _ = try? context.startTask(toRender: resizedImage, to: renderDestination)

//        defer {
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        print("\(debugPrefix(describing: #selector(draw(_:)))) \(executionTime)")
//        }
        commandBuffer.addScheduledHandler { [weak self] _ in
          guard let strongSelf = self else { return }
          strongSelf.renderSemaphore.signal()
        }
        commandBuffer.present(drawable)
      }
    }
  }

  private func resize(image: CIImage, in size: CGSize, resizeMode: HSResizeMode) -> CIImage? {
    guard let filter = lanczosScaleTransformFilter else {
      return nil
    }
    filter.setValue(image, forKey: kCIInputImageKey)
    filter.setValue(
      calculateScale(from: image.extent.size, in: size, resizeMode: resizeMode), forKey: kCIInputScaleKey
    )
    return filter.outputImage
  }

  public func captureDevicePointConverted(fromLayerPoint layerPoint: CGPoint) -> CGPoint {
    if let videoSize = HSCameraManager.shared.videoResolution {
      let scale = calculateScale(from: imageExtent.size, in: frame.size, resizeMode: resizeMode)
      return CGPoint(
        x: (layerPoint.x / scale) / CGFloat(videoSize.width),
        y: (layerPoint.y / scale) / CGFloat(videoSize.height)
      )
    }
    return .zero
  }
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
