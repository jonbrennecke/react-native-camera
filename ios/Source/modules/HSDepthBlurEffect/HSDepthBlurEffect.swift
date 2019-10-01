import Accelerate
import AVFoundation
import CoreImage
import HSCameraUtils

class HSDepthBlurEffect {
  public enum PreviewMode {
    case depth
    case portraitBlur
  }

  public struct WatermarkProperties {
    public let fileName: String
    public let fileExtension: String
    public let scale: Float
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

  private lazy var sourceAtopCompositingFilter: CIFilter? = {
    guard let filter = CIFilter(name: "CISourceAtopCompositing") else {
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

  private func applySourceAtopCompositingFilter(inputImage: CIImage, backgroundImage: CIImage) -> CIImage? {
    guard let sourceAtopCompositingFilter = sourceAtopCompositingFilter else {
      return nil
    }
    sourceAtopCompositingFilter.setValue(inputImage, forKey: kCIInputImageKey)
    sourceAtopCompositingFilter.setValue(backgroundImage, forKey: kCIInputBackgroundImageKey)
    return sourceAtopCompositingFilter.outputImage
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
    watermarkProperties: WatermarkProperties?,
    calibrationData _: AVCameraCalibrationData?,
    blurAperture: Float,
    scale: Float = 1,
    qualityFactor: Float = 0.1
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
      let disparityImage = HSImageBuffer(pixelBuffer: disparityPixelBuffer).makeCIImage()
    else {
      return nil
    }
    if case .depth = previewMode {
      guard let upsampleFilter = edgePreserveUpsampleFilter else {
        return nil
      }
      upsampleFilter.setValue(videoImage, forKey: kCIInputImageKey)
      upsampleFilter.setValue(disparityImage, forKey: "inputSmallImage")
      return upsampleFilter.outputImage
    }
    guard let depthBlurFilter = depthBlurEffectFilter else {
      return nil
    }
    depthBlurFilter.setValue(qualityFactor, forKey: "inputScaleFactor")
    depthBlurFilter.setValue(blurAperture, forKey: "inputAperture")
    depthBlurFilter.setValue(videoImage, forKey: kCIInputImageKey)
    depthBlurFilter.setValue(disparityImage, forKey: kCIInputDisparityImageKey)
    guard let depthBlurImage = depthBlurFilter.outputImage else {
      return nil
    }
    if let properties = watermarkProperties {
      return applyWatermark(
        to: depthBlurImage,
        properties: properties
      )
    } else {
      return depthBlurImage
    }
  }

  public func makeEffectImageWithoutScaling(
    previewMode: PreviewMode,
    disparityPixelBuffer: HSPixelBuffer,
    videoPixelBuffer: HSPixelBuffer,
    watermarkProperties: WatermarkProperties?,
    calibrationData _: AVCameraCalibrationData?,
    blurAperture: Float,
    qualityFactor: Float = 0.1
  ) -> CIImage? {
    guard
      let videoImage = HSImageBuffer(pixelBuffer: videoPixelBuffer).makeCIImage(),
      let disparityImage = HSImageBuffer(pixelBuffer: disparityPixelBuffer).makeCIImage()
    else {
      return nil
    }
    if case .depth = previewMode {
      guard let upsampleFilter = edgePreserveUpsampleFilter else {
        return nil
      }
      upsampleFilter.setValue(videoImage, forKey: kCIInputImageKey)
      upsampleFilter.setValue(disparityImage, forKey: "inputSmallImage")
      return upsampleFilter.outputImage
    }
    guard let depthBlurFilter = depthBlurEffectFilter else {
      return nil
    }
    depthBlurFilter.setValue(qualityFactor, forKey: "inputScaleFactor")
    depthBlurFilter.setValue(blurAperture, forKey: "inputAperture")
    depthBlurFilter.setValue(videoImage, forKey: kCIInputImageKey)
    depthBlurFilter.setValue(disparityImage, forKey: kCIInputDisparityImageKey)
    //    depthBlurFilter.setValue(calibrationData, forKey: "inputCalibrationData")
    //    depthBlurFilter.setValue(CIVector(cgRect: CGRect.zero), forKey: "inputFocusRect")
    guard let depthBlurImage = depthBlurFilter.outputImage else {
      return nil
    }
    if let properties = watermarkProperties {
      return applyWatermark(
        to: depthBlurImage,
        properties: properties
      )
    } else {
      return depthBlurImage
    }
  }

  private func applyWatermark(to image: CIImage, properties: WatermarkProperties) -> CIImage? {
    guard let watermarkCGImage = generateWatermarkCGImage(
      byResourceName: properties.fileName, extension: properties.fileExtension
    ) else {
      return image
    }
    let scale = CGFloat(properties.scale)
    let watermarkImage = CIImage(cgImage: watermarkCGImage)
    let transformedWatermarkImage = watermarkImage
      .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
      .transformed(by: CGAffineTransform(
        translationX: image.extent.width - watermarkImage.extent.width * scale - 20,
        y: 20
      ))
    return applySourceAtopCompositingFilter(
      inputImage: transformedWatermarkImage,
      backgroundImage: image
    )
  }

  private func generateWatermarkCGImage(byResourceName name: String, extension ext: String) -> CGImage? {
    guard let path = Bundle.main.path(forResource: name, ofType: ext) else {
      return nil
    }
    let url = URL(fileURLWithPath: path)
    guard
      let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    else {
      return nil
    }
    return image
  }
}
