import AVFoundation

class HSVideoCompositor: NSObject, AVVideoCompositing {
  private var renderingQueue = DispatchQueue(label: "com.jonbrennecke.hsvideocompositor.renderingqueue")
  private var renderingContextQueue = DispatchQueue(label: "com.jonbrennecke.hsvideocompositor.rendercontextqueue")

  private var renderContext: AVVideoCompositionRenderContext?

  var sourcePixelBufferAttributes = [
    kCVPixelBufferPixelFormatTypeKey: [kCVPixelFormatType_32BGRA]
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

  func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
    autoreleasepool {
      renderingQueue.async {
        if self.shouldCancelAllRequests {
          request.finishCancelledRequest()
          return
        }
        let trackID = CMPersistentTrackID(request.sourceTrackIDs[1].intValue)
        guard let pixelBuffer = request.sourceFrame(byTrackID: trackID) else {
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
}
