import AVFoundation
import CoreImage
import HSCameraUtils

class HSVideoCompositor: NSObject, AVVideoCompositing {
  private enum VideoCompositionRequestError: Error {
    case failedToComposePixelBuffer
  }

  private var renderingQueue = DispatchQueue(label: "com.jonbrennecke.hsvideocompositor.renderingqueue")
  private var renderContext: AVVideoCompositionRenderContext?

  private lazy var context = CIContext()
  private lazy var depthBlurEffect = HSDepthBlurEffect()

  public var depthTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
  public var videoTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
  public var isDepthPreviewEnabled: Bool = false
  public var isPortraitModeEnabled: Bool = false
  public var aperture: Float = 0

  private func composePixelBuffer(with request: AVAsynchronousVideoCompositionRequest) -> CVPixelBuffer? {
    if !isPortraitModeEnabled {
      return request.sourceFrame(byTrackID: videoTrackID)
    }
    guard
      let videoTrackPixelBuffer = request.sourceFrame(byTrackID: videoTrackID),
      let depthTrackPixelBuffer = request.sourceFrame(byTrackID: depthTrackID)
    else {
      return nil
    }
    guard
      let depthBlurImage = depthBlurEffect.makeEffectImage(
        previewMode: isDepthPreviewEnabled ? .depth : .portraitBlur,
        qualityMode: .exportQuality,
        disparityPixelBuffer: HSPixelBuffer(pixelBuffer: depthTrackPixelBuffer),
        videoPixelBuffer: HSPixelBuffer(pixelBuffer: videoTrackPixelBuffer),
        aperture: aperture
      ),
      let outputPixelBuffer = renderContext?.newPixelBuffer()
    else {
      return nil
    }
    withLockedBaseAddress(outputPixelBuffer, flags: CVPixelBufferLockFlags(rawValue: 0)) { _ in
      context.render(depthBlurImage, to: outputPixelBuffer)
    }
    return outputPixelBuffer
  }

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
    shouldCancelAllRequests = true
    renderingQueue.async { [weak self] in
      self?.shouldCancelAllRequests = false
    }
  }
}
