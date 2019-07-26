import AVFoundation
import CoreImage
import HSCameraUtils

class HSDepthBlurEffect {
  private let outputPixelBufferSize = Size<Int>(width: 480, height: 640)

  private lazy var outputPixelBufferPool: CVPixelBufferPool? = {
    createCVPixelBufferPool(
      size: outputPixelBufferSize,
      pixelFormatType: kCVPixelFormatType_32BGRA
    )
  }()

  public lazy var faceDetector: CIDetector? = {
    let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
    return CIDetector(ofType: CIDetectorTypeFace, context: nil, options: options)
  }()

  public func makeEffectImage(depthPixelBuffer: HSPixelBuffer, videoPixelBuffer: HSPixelBuffer) -> CIImage? {
    guard
      let faceDetector = faceDetector,
      let depthBlurFilter = buildDepthBlurCIFilter(),
      let videoImage = HSImageBuffer(pixelBuffer: videoPixelBuffer).makeCIImage(),
      let depthImage = HSImageBuffer(pixelBuffer: depthPixelBuffer).makeCIImage()
    else {
      return nil
    }

    let faces = faceDetector.features(in: videoImage)
    if let face = faces.first as? CIFaceFeature {
      if face.hasRightEyePosition {
        depthBlurFilter.setValue(CIVector(cgPoint: face.rightEyePosition), forKey: "inputRightEyePositions")
      }
      if face.hasLeftEyePosition {
        depthBlurFilter.setValue(CIVector(cgPoint: face.leftEyePosition), forKey: "inputLeftEyePositions")
      }
    }

    depthBlurFilter.setValue(videoImage, forKey: kCIInputImageKey)
    depthBlurFilter.setValue(depthImage, forKey: kCIInputDisparityImageKey)
    return depthBlurFilter.outputImage
  }
}

fileprivate func buildDepthBlurCIFilter() -> CIFilter? {
  guard let filter = CIFilter(name: "CIDepthBlurEffect") else {
    return nil
  }
  filter.setDefaults()
  filter.setValue(1, forKey: "inputScaleFactor")
  //    filter.setValue(inputCalibrationData, forKey: "inputCalibrationData")
  //    filter.setValue(inputAuxDataMetadata, forKey: "inputAuxDataMetadata")
//      filter.setValue(inputAperture, forKey: "inputAperture")
  //    filter.setValue(inputFocusRect, forKey: "inputFocusRect")
  return filter
}
