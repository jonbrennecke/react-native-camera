import CoreML
import HSCameraUtils
import Accelerate

public class HSSegmentation {
  private let model: HSSegmentationModel

  init(model: HSSegmentationModel) {
    self.model = model
  }

  public func runSegmentation(
    colorBuffer: HSPixelBuffer,
    depthBuffer: HSPixelBuffer,
    pixelBufferPool: CVPixelBufferPool
  ) throws -> HSPixelBuffer? {
    let input = HSSegmentationModelInput(
      color_image_input: colorBuffer.buffer,
      depth_image_input: depthBuffer.buffer
    )
    let output = try model.prediction(input: input)

    // convert multiarray to CVPixelBuffer
    
    let multiArray = output.segmentation_image_output
    let height = multiArray.shape[1].intValue
    let width = multiArray.shape[2].intValue
    let size = Size<Int>(width: width, height: height)

    let rawPixels: [Double] = convert(multiArray: multiArray)
    let bounds = rawPixels.bounds()
    
    var pixels = rawPixels.map { pixel -> UInt8 in
      let normalized = normalize(pixel, min: bounds.lowerBound, max: bounds.upperBound)
      let scaled = clamp(normalized * 255, min: 0, max: 255)
      return UInt8(exactly: scaled.rounded()) ?? 0
    }

    // create vImage_Buffer with data
    let bufferInfo = HSBufferInfo(pixelFormatType: kCVPixelFormatType_OneComponent8)
    let bytesPerPixel = bufferInfo.bytesPerPixel
    let destHeight = vImagePixelCount(size.height)
    let destWidth = vImagePixelCount(size.width)
    let destTotalBytes = size.height * size.width * bytesPerPixel
    let destBytesPerRow = size.width * bytesPerPixel
    guard let destData = malloc(destTotalBytes) else {
      return nil
    }
    
    // TODO: create vImage_Buffer directly with data
    memcpy(destData, &pixels, destTotalBytes)
    
    var destBuffer = vImage_Buffer(
      data: destData,
      height: destHeight,
      width: destWidth,
      rowBytes: destBytesPerRow
    )
    
    guard let destPixelBuffer = createPixelBuffer(with: pixelBufferPool) else {
      free(destData)
      return nil
    }
    
    var cgImageFormat = vImage_CGImageFormat(
      bitsPerComponent: UInt32(bufferInfo.bitsPerComponent),
      bitsPerPixel: UInt32(bufferInfo.bitsPerPixel),
      colorSpace: Unmanaged.passRetained(bufferInfo.colorSpace),
      bitmapInfo: bufferInfo.bitmapInfo,
      version: 0,
      decode: nil,
      renderingIntent: .defaultIntent
    )
    
    guard let cvImageFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(destPixelBuffer)?.takeRetainedValue() else {
      free(destData)
      return nil
    }
    vImageCVImageFormat_SetColorSpace(cvImageFormat, bufferInfo.colorSpace)
    
    let copyError = vImageBuffer_CopyToCVPixelBuffer(
      &destBuffer,
      &cgImageFormat,
      destPixelBuffer,
      cvImageFormat,
      nil,
      vImage_Flags(kvImageNoFlags)
    )
    
    if copyError != kvImageNoError {
      free(destData)
      return nil
    }
    free(destData)
    
    return HSPixelBuffer(pixelBuffer: destPixelBuffer)
  }
}

func convert<T: Numeric>(multiArray: MLMultiArray) -> [T] {
  let height = multiArray.shape[1].intValue
  let width = multiArray.shape[2].intValue
  let size = Size<Int>(width: width, height: height)
  let ptr = UnsafeMutablePointer<T>(OpaquePointer(multiArray.dataPointer))

  let heightStride = multiArray.strides[1].intValue
  let widthStride = multiArray.strides[2].intValue

  let count = size.width * size.height
  var pixels = [T](repeating: 0, count: count)

  for y in 0 ..< height {
    for x in 0 ..< width {
      let value = ptr[y * heightStride + x * widthStride]
      pixels[y * width + x] = value
    }
  }
  return pixels
}
