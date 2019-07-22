import AVFoundation
import CoreImage
import HSCameraUtils

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

/**
 inputRightEyePositions: CIVector
 inputCalibrationData: AVCameraCalibrationData
 inputChinPositions: CIVector
 inputLeftEyePositions: CIVector
 inputAuxDataMetadata: NSDictionary
 inputAperture: Double = 0,
 inputNosePositions: CIVector
 inputLumaNoiseScale: Double = 0
 inputScaleFactor: Double = 1
 inputFocusRect: CIVector
 */
fileprivate func buildDepthBlurCIFilter() -> CIFilter? {
  guard let filter = CIFilter(name: "CIDepthBlurEffect") else {
    return nil
  }
  filter.setDefaults()
  //    filter.setValue(    inputRightEyePositions, forKey: "inputRightEyePositions")
  //    filter.setValue(inputCalibrationData, forKey: "inputCalibrationData")
  //    filter.setValue(inputChinPositions, forKey: "inputChinPositions")
  //    filter.setValue(inputLeftEyePositions, forKey: "inputLeftEyePositions")
  //    filter.setValue(inputAuxDataMetadata, forKey: "inputAuxDataMetadata")
  //    filter.setValue(inputAperture, forKey: "inputAperture")
  //    filter.setValue(inputNosePositions, forKey: "inputNosePositions")
  //    filter.setValue(inputLumaNoiseScale, forKey: "inputLumaNoiseScale")
  filter.setValue(1, forKey: "inputScaleFactor")
  //    filter.setValue(inputFocusRect, forKey: "inputFocusRect")
  return filter
}
