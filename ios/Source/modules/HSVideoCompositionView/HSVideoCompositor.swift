import AVFoundation
import CoreImage
import HSCameraUtils

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
      renderingQueue.sync { // TODO: sync or async?
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

  private lazy var context = CIContext() // TODO: use metal context and NSNull color space
  private lazy var depthBlurEffect = HSDepthBlurEffect()

  private func composePixelBuffer(with request: AVAsynchronousVideoCompositionRequest) -> CVPixelBuffer? {
    if isDepthPreviewEnabled {
      return request.sourceFrame(byTrackID: depthTrackID)
    }
    guard
      let videoPixelBuffer = request.sourceFrame(byTrackID: videoTrackID),
      let depthPixelBuffer = request.sourceFrame(byTrackID: depthTrackID)
    else {
      return nil
    }
    guard
      let depthBlurImage = depthBlurEffect.makeEffectImage(
        depthPixelBuffer: HSPixelBuffer(pixelBuffer: depthPixelBuffer),
        videoPixelBuffer: HSPixelBuffer(pixelBuffer: videoPixelBuffer)
      ),
      let outputPixelBuffer = renderContext?.newPixelBuffer()
    else {
      return nil
    }
    context.render(depthBlurImage, to: outputPixelBuffer)
    return outputPixelBuffer
  }
}

struct HSDepthBlurEffect {
  private let outputPixelBufferSize = Size<Int>(width: 480, height: 640)

  private lazy var outputPixelBufferPool: CVPixelBufferPool? = {
    createCVPixelBufferPool(
      size: outputPixelBufferSize,
      pixelFormatType: kCVPixelFormatType_32BGRA
    )
  }()

  public func makeEffectImage(depthPixelBuffer: HSPixelBuffer, videoPixelBuffer: HSPixelBuffer) -> CIImage? {
    guard
      let depthBlurFilter = buildDepthBlurCIFilter(),
      let videoImage = HSImageBuffer(pixelBuffer: videoPixelBuffer).makeCIImage(),
      let depthImage = HSImageBuffer(pixelBuffer: depthPixelBuffer).makeCIImage()
    else {
      return nil
    }
    depthBlurFilter.setValue(videoImage, forKey: kCIInputImageKey)
    depthBlurFilter.setValue(depthImage, forKey: kCIInputDisparityImageKey)
    return depthBlurFilter.outputImage
  }
}

//  (inputRightEyePositions:CIVector,inputCalibrationData:AVCameraCalibrationData,inputChinPositions:CIVector,inputLeftEyePositions:CIVector,inputAuxDataMetadata:NSDictionary,inputAperture:Double = 0,inputNosePositions:CIVector,inputLumaNoiseScale:Double = 0,inputScaleFactor:Double = 1,inputFocusRect:CIVector)
fileprivate func buildDepthBlurCIFilter() -> CIFilter? {
  guard let filter = CIFilter(name: "CIDepthBlurEffect") else {
    return nil
  }
  filter.setDefaults()
  //    filter.setValue(inputRightEyePositions, forKey: "inputRightEyePositions")
  //    filter.setValue(inputCalibrationData, forKey: "inputCalibrationData")
  //    filter.setValue(inputChinPositions, forKey: "inputChinPositions")
  //    filter.setValue(inputLeftEyePositions, forKey: "inputLeftEyePositions")
  //    filter.setValue(inputAuxDataMetadata, forKey: "inputAuxDataMetadata")
  //    filter.setValue(inputAperture, forKey: "inputAperture")
  //    filter.setValue(inputNosePositions, forKey: "inputNosePositions")
  //    filter.setValue(inputLumaNoiseScale, forKey: "inputLumaNoiseScale")
  filter.setValue(1, forKey: "inputScaleFactor")
  //    filter.setValue(inputFocusRect, forKey: "inputFocusRect")
  //    filter.setValue(inputDisparityImage, forKey: "inputDisparityImage")
  return filter
}
