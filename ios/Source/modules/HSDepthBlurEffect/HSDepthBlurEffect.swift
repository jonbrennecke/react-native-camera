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

//  private lazy var context = CIContext(mtlDevice: mtlDevice)
  private lazy var context = CIContext()
//  private lazy var context = CIContext(options: [
////    CIContextOption.useSoftwareRenderer: true,
////    CIContextOption.workingColorSpace: CGColorSpaceCreateDeviceGray(),
////    CIContextOption.outputColorSpace: CGColorSpaceCreateDeviceGray(),
//    CIContextOption.workingColorSpace: CGColorSpaceCreateDeviceGray(),
////    CIContextOption.workingFormat: kCVPixelFormatType_OneComponent8
////    kCIImageColorSpace: null
//  ])

  public lazy var faceDetector: CIDetector? = {
    let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
    return CIDetector(ofType: CIDetectorTypeFace, context: nil, options: options)
  }()
  
  public enum PreviewMode {
    case depth
    case portraitBlur
  }

  public func makeEffectImage(
    previewMode: PreviewMode,
    depthPixelBuffer: HSPixelBuffer, // Depth or disparity
    videoPixelBuffer: HSPixelBuffer,
    aperture: Float
  ) -> CIImage? {
    let depthOrDisparityImage = CIImage(cvPixelBuffer: depthPixelBuffer.buffer)
    guard let normalizedDisparityImage = normalize(image: depthOrDisparityImage, context: context) else {
      return nil
    }
    if case .depth = previewMode {
      return normalizedDisparityImage.cropped(to: normalizedDisparityImage.extent)
    }
    guard let depthBlurFilter = buildDepthBlurCIFilter(aperture: aperture) else {
      return nil
    }
    let videoImage = CIImage(cvPixelBuffer: videoPixelBuffer.buffer)
    
    // scale disparity image
//    let scaledDisparityImage = videoImage
//      .applyingFilter("CIEdgePreserveUpsampleFilter", parameters: [
//        "inputSmallImage": normalizedDisparityImage,
//      ])
    
    //      let faceDetector = faceDetector,
    // find face features
//    let faces = faceDetector.features(in: videoImage)
//    if let face = faces.first as? CIFaceFeature {
//      if face.hasRightEyePosition {
//        depthBlurFilter.setValue(CIVector(cgPoint: face.rightEyePosition), forKey: "inputRightEyePositions")
//      }
//      if face.hasLeftEyePosition {
//        depthBlurFilter.setValue(CIVector(cgPoint: face.leftEyePosition), forKey: "inputLeftEyePositions")
//      }
//    }

    depthBlurFilter.setValue(videoImage, forKey: kCIInputImageKey)
    depthBlurFilter.setValue(normalizedDisparityImage, forKey: kCIInputDisparityImageKey)
    return depthBlurFilter.outputImage
  }
}

fileprivate func normalize(image inputImage: CIImage, context: CIContext) -> CIImage? {
  guard
    let (min, max) = minMax(image: inputImage, context: context),
    let normalizeFilter = applyNormalizeFilter(inputImage: inputImage, min: min, max: max),
    let normalizedImage = normalizeFilter.outputImage
  else {
    return nil
  }
  return normalizedImage
}

fileprivate func minMax(image inputImage: CIImage, context: CIContext = CIContext()) -> (min: Float, max: Float)? {
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
  return (min: output[0], max: output[1])
}

fileprivate func minMaxFast(image inputImage: CIImage, context: CIContext = CIContext()) -> (min: Float, max: Float)? {
  guard
    let minMaxFilter = areaMinMaxRedFilter(inputImage: inputImage),
    let areaMinMaxImage = minMaxFilter.outputImage
    else {
      return nil
  }
  let startTime = CFAbsoluteTimeGetCurrent()
  var pixels = [UInt8](repeating: 0, count: 2)
  context.render(areaMinMaxImage,
                 toBitmap: &pixels,
                 rowBytes: 4,
                 bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                 format: CIFormat.RG8,
                 colorSpace: nil)
  let executionTime = CFAbsoluteTimeGetCurrent() - startTime
  print("Execution Time: \(executionTime)")
  
  return (min: Float(pixels[0]) / 255, max: Float(pixels[1]) / 255)
}

fileprivate func applyNormalizeFilter(inputImage: CIImage, min: Float, max: Float) -> CIFilter? {
  guard let filter = CIFilter(name: "CIColorMatrix") else {
    return nil
  }
  let slope = CGFloat(1 / (max - min))
  let bias = -CGFloat(min) * slope
  filter.setDefaults()
  filter.setValue(CIVector(x: slope, y: 0, z: 0, w: 0), forKey: "inputRVector")
  filter.setValue(CIVector(x: 0, y: slope, z: 0, w: 0), forKey: "inputGVector")
  filter.setValue(CIVector(x: 0, y: 0, z: slope, w: 0), forKey: "inputBVector")
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
