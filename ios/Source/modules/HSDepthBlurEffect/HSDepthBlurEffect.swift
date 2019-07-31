import Accelerate
import AVFoundation
import CoreImage
import HSCameraUtils

class HSDepthBlurEffect {
  private lazy var mtlDevice: MTLDevice! = {
    guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
      fatalError("Failed to create Metal device")
    }
    return mtlDevice
  }()

  private lazy var context = CIContext(mtlDevice: mtlDevice)

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

//    let isDisparity = depthPixelBuffer.pixelFormatType == kCVPixelFormatType_DisparityFloat32
//      || depthPixelBuffer.pixelFormatType == kCVPixelFormatType_DisparityFloat16
//    let disparityImage = isDisparity ? depthOrDisparityImage : depthOrDisparityImage.applyingFilter("CIDepthToDisparity")
//    let scaledDisparityImage = videoImage.applyingFilter("CIEdgePreserveUpsampleFilter", parameters: [
//      "inputSmallImage": disparityImage,
//    ])
    return normalize(image: depthOrDisparityImage, context: context)

//    depthBlurFilter.setValue(videoImage, forKey: kCIInputImageKey)
//    depthBlurFilter.setValue(scaledDisparityImage, forKey: kCIInputDisparityImageKey)
//    return depthBlurFilter.outputImage
  }
}

fileprivate func normalize(image inputImage: CIImage, context: CIContext) -> CIImage? {
  guard
    let minMaxFilter = areaMinMaxRedFilter(inputImage: inputImage),
    let areaMinMaxImage = minMaxFilter.outputImage
  else {
    return nil
  }
  var pixels = [UInt16](repeating: 0, count: 2)
  context.render(areaMinMaxImage,
                 toBitmap: &pixels,
                 rowBytes: 32,
                 bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                 format: CIFormat.RGh,
                 colorSpace: nil)
  var output = [Float](repeating: 0, count: 2)
  var bufferFloat16 = vImage_Buffer(data: &pixels, height: 1, width: 2, rowBytes: 2)
  var bufferFloat32 = vImage_Buffer(data: &output, height: 1, width: 2, rowBytes: 4)
  let error = vImageConvert_Planar16FtoPlanarF(&bufferFloat16, &bufferFloat32, 0)
  if error != kvImageNoError {
    return nil
  }
  let min = output[0]
  let max = output[1]
  guard
    let normalizeFilter = normalizeFilter(inputImage: inputImage, min: min, max: max),
    let normalizedImage = normalizeFilter.outputImage
  else {
    return nil
  }
  return normalizedImage
}

fileprivate func normalizeFilter(inputImage: CIImage, min: Float, max: Float) -> CIFilter? {
  guard let filter = CIFilter(name: "CIColorMatrix") else {
    return nil
  }
  let slope = CGFloat(1 / (max - min))
  let bias = -CGFloat(min) * slope
  filter.setDefaults()
  filter.setValue(CIVector(x: slope, y: 0, z: 0, w: 0), forKey: "inputRVector")
  filter.setValue(CIVector(x: 0, y: slope, z: 0, w: 0), forKey: "inputGVector")
  filter.setValue(CIVector(x: 0, y: 0, z: slope, w: 0), forKey: "inputBVector")
//  filter.setValue(CIVector(x: 0, y: 0, z: 0, w: slope), forKey: "inputAVector")
  filter.setValue(CIVector(x: bias, y: bias, z: bias, w: 0), forKey: "inputBiasVector")
  filter.setValue(inputImage, forKey: kCIInputImageKey)
  return filter
}

fileprivate func areaMinMaxRedFilter(
  inputImage: CIImage, inputExtent: CIVector? = nil
) -> CIFilter? {
  guard let filter = CIFilter(name: "CIAreaMinMaxRed") else {
    return nil
  }
  filter.setDefaults()
  filter.setValue(inputImage, forKey: kCIInputImageKey)
  filter.setValue(inputExtent ?? inputImage.extent, forKey: kCIInputExtentKey)
  return filter
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
