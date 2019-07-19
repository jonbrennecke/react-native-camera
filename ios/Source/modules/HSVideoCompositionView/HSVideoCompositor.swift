import AVFoundation

class HSVideoCompositor: NSObject, AVVideoCompositing {
  private var renderingQueue = DispatchQueue(label: "com.jonbrennecke.hsvideocompositor.renderingqueue")
  private var renderingContextQueue = DispatchQueue(label: "com.jonbrennecke.hsvideocompositor.rendercontextqueue")
  private var renderContext: AVVideoCompositionRenderContext?
  
  internal var depthTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
  internal var videoTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
  internal var isDepthPreviewEnabled: Bool = false

  var sourcePixelBufferAttributes = [
    kCVPixelBufferPixelFormatTypeKey: [kCVPixelFormatType_32BGRA],
  ] as [String: Any]?

  var requiredPixelBufferAttributesForRenderContext = [
    kCVPixelBufferPixelFormatTypeKey: [kCVPixelFormatType_32BGRA],
  ] as [String: Any]

  var shouldCancelAllRequests: Bool = false

  func renderContextChanged(_ newContext: AVVideoCompositionRenderContext) {
    renderingContextQueue.sync {
      renderContext = newContext
    }
  }
  
  enum VideoCompositionRequestError: Error {
    case failedToComposePixelBuffer
  }

  func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
    autoreleasepool {
      renderingQueue.async {
        if self.shouldCancelAllRequests {
          request.finishCancelledRequest()
          return
        }
        guard let pixelBuffer = self.composePixelBuffer(with: request) else {
          request.finish(with: VideoCompositionRequestError.failedToComposePixelBuffer)
          return
        }
        request.finish(withComposedVideoFrame: pixelBuffer)
      }
    }
  }

  func cancelAllPendingVideoCompositionRequests() {
    renderingQueue.sync {
      shouldCancelAllRequests = true
    }
    renderingQueue.async {
      self.shouldCancelAllRequests = false
    }
  }
  
  private func composePixelBuffer(with request: AVAsynchronousVideoCompositionRequest) -> CVPixelBuffer? {
    let previewTrackID = isDepthPreviewEnabled ? depthTrackID : videoTrackID
    guard let pixelBuffer = request.sourceFrame(byTrackID: previewTrackID) else {
      return nil
    }
    return pixelBuffer
  }
}
