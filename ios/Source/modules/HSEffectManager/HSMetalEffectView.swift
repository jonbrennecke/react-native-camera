import AVFoundation
import HSCameraUtils
import MetalKit
import UIKit

class HSMetalEffectView: MTKView {
  private lazy var commandQueue: MTLCommandQueue! = {
    guard let commandQueue = device?.makeCommandQueue(maxCommandBufferCount: 10) else {
      fatalError("Failed to create Metal command queue")
    }
    return commandQueue
  }()

  private lazy var context: CIContext! = {
    guard let device = device else {
      fatalError("Failed to get Metal device")
    }
    return CIContext(mtlDevice: device, options: [CIContextOption.workingColorSpace: NSNull()])
  }()

  private let isDebugLogEnabled = false
  private var imageExtent: CGRect = .zero
  private let colorSpace = CGColorSpaceCreateDeviceRGB()
  private weak var effectManager: HSEffectManager?

  public var resizeMode: HSResizeMode = .scaleAspectWidth
  public var blurAperture: Float = 0

  public init(effectManager: HSEffectManager) {
    guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
      fatalError("Failed to create Metal device")
    }
    super.init(frame: .zero, device: mtlDevice)
    self.effectManager = effectManager
    framebufferOnly = false
    preferredFramesPerSecond = 30
    autoResizeDrawable = true
    enableSetNeedsDisplay = false
    drawableSize = frame.size
  }

  required init(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func draw(_ rect: CGRect) {
    autoreleasepool {
      super.draw(rect)
      let startTime = CFAbsoluteTimeGetCurrent()
      defer {
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        if isDebugLogEnabled {
          print("\(debugPrefix(describing: #selector(draw(_:)))) \(executionTime)")
        }
      }
      guard let image = effectManager?.makeEffectImage(blurAperture: blurAperture) else {
        return
      }
      imageExtent = image.extent
      present(image: image, resizeMode: resizeMode)
    }
  }

  private func debugPrefix(describing selector: Selector) -> String {
    return """
    [\(String(describing: HSMetalEffectView.self)) \(String(describing: selector))]:
    """
  }

  private func present(image: CIImage, resizeMode: HSResizeMode) {
    if let commandBuffer = commandQueue.makeCommandBuffer(), let drawable = currentDrawable {
      if drawable.presentedTime != .zero {
        return
      }
      guard let resizedImage = resize(image: image, in: frame.size, resizeMode: resizeMode) else {
        return
      }
      context.render(
        resizedImage,
        to: drawable.texture,
        commandBuffer: commandBuffer,
        bounds: resizedImage.extent,
        colorSpace: colorSpace
      )
      commandBuffer.present(drawable)
      commandBuffer.commit()
    }
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
