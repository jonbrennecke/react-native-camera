import Accelerate
import AVFoundation
import CoreImage
import HSCameraUtils

class HSDepthBlurEffect {
  public enum QualityMode {
    case previewQuality
    case exportQuality
  }

  public enum PreviewMode {
    case depth
    case portraitBlur
  }

  private lazy var depthBlurEffectFilter: CIFilter? = {
    guard let filter = CIFilter(name: "CIDepthBlurEffect") else {
      return nil
    }
    filter.setDefaults()
    return filter
  }()

  private lazy var edgePreserveUpsampleFilter: CIFilter? = {
    guard let filter = CIFilter(name: "CIEdgePreserveUpsampleFilter") else {
      return nil
    }
    filter.setDefaults()
    return filter
  }()

  public func makeEffectImage(
    previewMode: PreviewMode,
    qualityMode _: QualityMode,
    disparityPixelBuffer: HSPixelBuffer,
    videoPixelBuffer: HSPixelBuffer,
    aperture: Float,
    shouldNormalize: Bool = false
  ) -> CIImage? {
    guard
      let disparityImage = HSImageBuffer(pixelBuffer: disparityPixelBuffer).makeCIImage(),
      let videoImage = HSImageBuffer(pixelBuffer: videoPixelBuffer).makeCIImage()
    else {
      return nil
    }

    guard let upsampleFilter = edgePreserveUpsampleFilter else {
      return nil
    }
    upsampleFilter.setValue(videoImage, forKey: kCIInputImageKey)
    upsampleFilter.setValue(disparityImage, forKey: "inputSmallImage")
    guard let upsampledDisparityImage = upsampleFilter.outputImage else {
      return nil
    }

    if case .depth = previewMode {
      return upsampledDisparityImage
    }
    guard let depthBlurFilter = depthBlurEffectFilter else {
      return nil
    }
    depthBlurFilter.setValue(0.1, forKey: "inputScaleFactor")
    depthBlurFilter.setValue(aperture, forKey: "inputAperture")
    depthBlurFilter.setValue(videoImage, forKey: kCIInputImageKey)
    depthBlurFilter.setValue(upsampledDisparityImage, forKey: kCIInputDisparityImageKey)
    return depthBlurFilter.outputImage
  }
}

fileprivate func composeDisparityImage(pixelBuffer: HSPixelBuffer) -> CIImage? {
  return HSImageBuffer(pixelBuffer: pixelBuffer).makeCIImage()
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
  var pixels = [UInt16](repeating: 0, count: 4)
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
  var pixels = [UInt8](repeating: 0, count: 4)
  context.render(areaMinMaxImage,
                 toBitmap: &pixels,
                 rowBytes: 4,
                 bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                 format: CIFormat.RGBA8,
                 colorSpace: nil)
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
