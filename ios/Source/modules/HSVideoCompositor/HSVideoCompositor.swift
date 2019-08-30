import AVFoundation
import CoreImage
import HSCameraUtils
import Metal

class HSVideoCompositor: NSObject, AVVideoCompositing {
  private enum VideoCompositionRequestError: Error {
    case failedToComposePixelBuffer
  }

  private var renderingQueue = DispatchQueue(label: "com.jonbrennecke.hsvideocompositor.renderingqueue")
  private var renderContext: AVVideoCompositionRenderContext?

  private lazy var context: CIContext! = {
    guard let device = MTLCreateSystemDefaultDevice() else {
      fatalError("Failed to get Metal device")
    }
    return CIContext(mtlDevice: device, options: [CIContextOption.workingColorSpace: NSNull()])
  }()

  private lazy var depthBlurEffect = HSDepthBlurEffect()

  public var depthTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
  public var videoTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
  public var previewMode: HSEffectPreviewMode = .portraitMode
  public var aperture: Float = 0 // TODO: rename to blurAperture

  // MARK: - AVVideoCompositing implementation

  var sourcePixelBufferAttributes = [
    kCVPixelBufferPixelFormatTypeKey: [kCVPixelFormatType_32BGRA],
  ] as [String: Any]?

  var requiredPixelBufferAttributesForRenderContext = [
    kCVPixelBufferPixelFormatTypeKey: [kCVPixelFormatType_32BGRA],
  ] as [String: Any]

  var shouldCancelAllRequests: Bool = false

  func renderContextChanged(_ newContext: AVVideoCompositionRenderContext) {
    renderingQueue.sync { [weak self] in
      self?.renderContext = newContext
    }
  }

  func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
    autoreleasepool {
      renderingQueue.async { [weak self] in
        guard let strongSelf = self else { return }
        if strongSelf.shouldCancelAllRequests {
          request.finishCancelledRequest()
          return
        }
        if let pixelBuffer = strongSelf.composePixelBuffer(with: request) {
          request.finish(withComposedVideoFrame: pixelBuffer)
        } else {
          // at least try to generate a blank pixel buffer
          if let pixelBuffer = strongSelf.renderContext?.newPixelBuffer() {
            request.finish(withComposedVideoFrame: pixelBuffer)
            return
          }
          request.finish(with: VideoCompositionRequestError.failedToComposePixelBuffer)
        }
      }
    }
  }

  func cancelAllPendingVideoCompositionRequests() {
    renderingQueue.sync { shouldCancelAllRequests = true }
    renderingQueue.async { [weak self] in
      self?.shouldCancelAllRequests = false
    }
  }

  // MARK: - Utilities

  private func composePixelBuffer(with request: AVAsynchronousVideoCompositionRequest) -> CVPixelBuffer? {
    return autoreleasepool {
      if case .normal = previewMode {
        return request.sourceFrame(byTrackID: videoTrackID)
      }
      guard
        let videoCVPixelBuffer = request.sourceFrame(byTrackID: videoTrackID),
        let disparityCVPixelBuffer = request.sourceFrame(byTrackID: depthTrackID)
      else {
        return nil
      }
      guard
        let effectImage = depthBlurEffect.makeEffectImageWithoutScaling(
          previewMode: previewMode == .depth ? .depth : .portraitBlur,
          disparityPixelBuffer: HSPixelBuffer(pixelBuffer: disparityCVPixelBuffer),
          videoPixelBuffer: HSPixelBuffer(pixelBuffer: videoCVPixelBuffer),
          calibrationData: nil,
          blurAperture: aperture,
          qualityFactor: 0.1
        ),
        let outputPixelBuffer = renderContext?.newPixelBuffer()
      else {
        return nil
      }
      context.render(
        effectImage,
        to: outputPixelBuffer,
        bounds: effectImage.extent,
        colorSpace: nil
      )
      return outputPixelBuffer
    }
  }
}
