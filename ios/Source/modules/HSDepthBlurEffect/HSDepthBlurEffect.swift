import AVFoundation
import CoreImage
import HSCameraUtils

class HSDepthBlurEffect {
  public lazy var faceDetector: CIDetector? = {
    let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
    return CIDetector(ofType: CIDetectorTypeFace, context: nil, options: options)
  }()

  public func makeEffectImage(
    depthPixelBuffer: HSPixelBuffer, // Depth or disparity
    videoPixelBuffer: HSPixelBuffer,
    aperture: Float
  ) -> CIImage? {
    guard
      let faceDetector = faceDetector,
      let depthBlurFilter = buildDepthBlurCIFilter(aperture: aperture),
      let videoImage = HSImageBuffer(pixelBuffer: videoPixelBuffer).makeCIImage(),
      let depthOrDisparityImage = HSImageBuffer(pixelBuffer: depthPixelBuffer).makeCIImage()
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

    let isDisparity = depthPixelBuffer.pixelFormatType == kCVPixelFormatType_DisparityFloat32
      || depthPixelBuffer.pixelFormatType == kCVPixelFormatType_DisparityFloat16
    let disparityImage = isDisparity ? depthOrDisparityImage : depthOrDisparityImage.applyingFilter("CIDepthToDisparity")
    let scaledDisparityImage = videoImage.applyingFilter("CIEdgePreserveUpsampleFilter", parameters: [
      "inputSmallImage": disparityImage,
    ])
    depthBlurFilter.setValue(videoImage, forKey: kCIInputImageKey)
    depthBlurFilter.setValue(scaledDisparityImage, forKey: kCIInputDisparityImageKey)
    return depthBlurFilter.outputImage
  }
}

fileprivate func buildDepthBlurCIFilter(aperture: Float) -> CIFilter? {
  guard let filter = CIFilter(name: "CIDepthBlurEffect") else {
    return nil
  }
  filter.setDefaults()
  filter.setValue(1, forKey: "inputScaleFactor")
  filter.setValue(aperture, forKey: "inputAperture")
  //    filter.setValue(inputCalibrationData, forKey: "inputCalibrationData")
  //    filter.setValue(inputAuxDataMetadata, forKey: "inputAuxDataMetadata")
  //    filter.setValue(inputFocusRect, forKey: "inputFocusRect")
  return filter
}
