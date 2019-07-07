import Accelerate
import CoreML
import HSCameraUtils

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

    // create vImage_Buffer with data
    let bufferInfo = HSBufferInfo(pixelFormatType: kCVPixelFormatType_OneComponent8)
    let bytesPerPixel = bufferInfo.bytesPerPixel
    let destHeight = vImagePixelCount(size.height)
    let destWidth = vImagePixelCount(size.width)
    let destBytesPerRow = size.width * bytesPerPixel
    var pixels = convertMultiArrayToPixels(multiArray)

    var destBuffer = vImage_Buffer(
      data: &pixels,
      height: destHeight,
      width: destWidth,
      rowBytes: destBytesPerRow
    )

    guard let destPixelBuffer = createPixelBuffer(with: pixelBufferPool) else {
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
      return nil
    }

    return HSPixelBuffer(pixelBuffer: destPixelBuffer)
  }
}

fileprivate func convertMultiArrayToPixels(_ multiArray: MLMultiArray) -> [UInt8] {
  let height = multiArray.shape[1].intValue
  let width = multiArray.shape[2].intValue
  let size = Size<Int>(width: width, height: height)
  let ptr = UnsafeMutablePointer<Double>(OpaquePointer(multiArray.dataPointer))

  let heightStride = multiArray.strides[1].intValue
  let widthStride = multiArray.strides[2].intValue

  let forEachPixel = { (body: (Double, Int, Int) -> Void) in
    for y in 0 ..< height {
      for x in 0 ..< width {
        let value = ptr[y * heightStride + x * widthStride]
        body(value, x, y)
      }
    }
  }

  let minMax = bounds({ body in
    forEachPixel { pixel, _, _ in
      body(pixel)
    }
  })

  let count = size.width * size.height
  var pixels = [UInt8](repeating: 0, count: count)
  forEachPixel { pixel, x, y in
    let normalized = normalize(pixel, min: minMax.lowerBound, max: minMax.upperBound)
    let scaled = clamp(normalized * 255, min: 0, max: 255)
    pixels[y * width + x] = UInt8(exactly: scaled.rounded()) ?? 0
  }

  return pixels
}
