import Accelerate
import AVFoundation
import CoreImage
import HSCameraUtils

class HSDepthBlurEffect {
  public enum PreviewMode {
    case depth
    case portraitBlur
  }

  private lazy var metalDevice: MTLDevice! = {
    guard let device = MTLCreateSystemDefaultDevice() else {
      fatalError("Failed to get Metal device")
    }
    return device
  }()

  private lazy var context: CIContext = {
    guard let device = metalDevice else {
      fatalError("Failed to get Metal device")
    }
    return CIContext(mtlDevice: device, options: [
      .workingColorSpace: NSNull(),
      .highQualityDownsample: false,
    ])
  }()

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

  private lazy var lanczosScaleTransformFilter: CIFilter? = {
    guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
      return nil
    }
    filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
    return filter
  }()

  private lazy var colorMatrixFilter: CIFilter? = {
    guard let filter = CIFilter(name: "CIColorMatrix") else {
      return nil
    }
    filter.setDefaults()
    return filter
  }()

  private lazy var areaMinMaxRedFilter: CIFilter? = {
    guard let filter = CIFilter(name: "CIAreaMinMaxRed") else {
      return nil
    }
    filter.setDefaults()
    return filter
  }()

  fileprivate func normalize(image inputImage: CIImage, context: CIContext = CIContext()) -> CIImage? {
    guard
      let (min, max) = minMax(image: inputImage, context: context),
      let normalizeFilter = applyNormalizeFilter(inputImage: inputImage, min: min, max: max),
      let normalizedImage = normalizeFilter.outputImage
    else {
      return nil
    }
    print(min, max)
    return normalizedImage
  }

  fileprivate func minMax(image inputImage: CIImage, context: CIContext = CIContext()) -> (min: Float, max: Float)? {
    guard
      let minMaxFilter = applyAreaMinMaxRedFilter(inputImage: inputImage),
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

  private func applyAreaMinMaxRedFilter(inputImage: CIImage, inputExtent: CIVector? = nil) -> CIFilter? {
    guard let filter = areaMinMaxRedFilter else {
      return nil
    }
    filter.setValue(inputImage, forKey: kCIInputImageKey)
    filter.setValue(inputExtent ?? inputImage.extent, forKey: kCIInputExtentKey)
    return filter
  }

  private func applyNormalizeFilter(inputImage: CIImage, min: Float, max: Float) -> CIFilter? {
    guard let filter = colorMatrixFilter else {
      return nil
    }
    let slope = CGFloat(1 / (max - min))
    let bias = -CGFloat(min) * slope
    filter.setValue(CIVector(x: slope, y: 0, z: 0, w: 0), forKey: "inputRVector")
    filter.setValue(CIVector(x: 0, y: slope, z: 0, w: 0), forKey: "inputGVector")
    filter.setValue(CIVector(x: 0, y: 0, z: slope, w: 0), forKey: "inputBVector")
    filter.setValue(CIVector(x: bias, y: bias, z: bias, w: 0), forKey: "inputBiasVector")
    filter.setValue(inputImage, forKey: kCIInputImageKey)
    return filter
  }
  
  private var pixelBufferPool: CVPixelBufferPool?
  
  private func createPool(size: Size<Int>) -> CVPixelBufferPool? {
    guard let pool = pixelBufferPool else {
      pixelBufferPool = createCVPixelBufferPool(
        size: size,
        pixelFormatType: kCVPixelFormatType_32BGRA
      )
      return pixelBufferPool
    }
    return pool
  }
  
  private var imageBufferResizer: HSImageBufferResizer?
  
  private func createImageBufferResizer(size: Size<Int>) -> HSImageBufferResizer? {
    guard let resizer = imageBufferResizer, size == resizer.size else {
      imageBufferResizer = HSImageBufferResizer(
        size: size,
        bufferInfo: HSBufferInfo(pixelFormatType: kCVPixelFormatType_32BGRA)
      )
      return imageBufferResizer
    }
    return resizer
  }
  
  // MARK: - public interface

  public func makeEffectImage(
    previewMode: PreviewMode,
    disparityPixelBuffer: HSPixelBuffer,
    videoPixelBuffer: HSPixelBuffer,
    calibrationData: AVCameraCalibrationData?,
    scale: Float,
    aperture: Float
  ) -> CIImage? {
    let scaledSize = Size<Int>(
      width: Int((Float(videoPixelBuffer.size.width) * scale).rounded()),
      height: Int((Float(videoPixelBuffer.size.height) * scale).rounded())
    )
    let videoImageBuffer = HSImageBuffer(pixelBuffer: videoPixelBuffer)
    guard
      let resizer = createImageBufferResizer(size: scaledSize),
      let videoImage = resizer
        .resize(imageBuffer: videoImageBuffer)?
        .makeCIImage(),
      let disparityImage = HSImageBuffer(pixelBuffer: disparityPixelBuffer).makeCIImage(),
      let upsampleFilter = edgePreserveUpsampleFilter
    else {
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
    depthBlurFilter.setValue(0.05, forKey: "inputScaleFactor") // TODO: use inputScaleFactor: 1 for final export
    depthBlurFilter.setValue(aperture, forKey: "inputAperture")
    depthBlurFilter.setValue(videoImage, forKey: kCIInputImageKey)
    depthBlurFilter.setValue(upsampledDisparityImage, forKey: kCIInputDisparityImageKey)
    depthBlurFilter.setValue(calibrationData, forKey: "inputCalibrationData")
    return depthBlurFilter.outputImage
  }

  public func makeEffectImage(
    previewMode: PreviewMode,
    disparityPixelBuffer: HSPixelBuffer,
    videoPixelBuffer: HSPixelBuffer,
    aperture: Float,
    shouldNormalize _: Bool = false
  ) -> CIImage? {
    guard
      let disparityImage = HSImageBuffer(pixelBuffer: disparityPixelBuffer).makeCIImage(),
      let videoImage = HSImageBuffer(pixelBuffer: videoPixelBuffer).makeCIImage()
    else {
      return nil
    }

    // upsample the depth image to match the video image
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
