import Accelerate
import CoreML
import HSCameraUtils

internal func createSegmentationMask(
  model: HSSegmentationModel,
  colorBuffer: HSPixelBuffer,
  depthBuffer: HSPixelBuffer,
  pixelBufferPool: CVPixelBufferPool
) throws -> HSPixelBuffer? {
  let input = HSSegmentationModelInput(
    color_image_input: colorBuffer.buffer,
    depth_image_input: depthBuffer.buffer
  )
  let startTime = CFAbsoluteTimeGetCurrent()
  let output = try model.prediction(input: input)
  let endTime = CFAbsoluteTimeGetCurrent()
  print("predict: execution time: \(endTime - startTime)")

  // convert multiarray to pixel data
  let multiArray = output.segmentation_image_output
  let height = multiArray.shape[1].intValue
  let width = multiArray.shape[2].intValue
  let size = Size<Int>(width: width, height: height)
  var pixels = convertMultiArrayToPixels(multiArray)

  // create vImage_Buffer with data
  let bufferInfo = HSBufferInfo(pixelFormatType: kCVPixelFormatType_OneComponent8)
  let bytesPerPixel = bufferInfo.bytesPerPixel
  let destBytesPerRow = size.width * bytesPerPixel
  var destBuffer = vImage_Buffer(
    data: &pixels,
    height: vImagePixelCount(size.height),
    width: vImagePixelCount(size.width),
    rowBytes: destBytesPerRow
  )
  guard
    var destPixelBuffer = createPixelBuffer(with: pixelBufferPool),
    case .some = copyVImageBuffer(&destBuffer, to: &destPixelBuffer, bufferInfo: bufferInfo)
  else {
    return nil
  }
  return HSPixelBuffer(pixelBuffer: destPixelBuffer)
}

fileprivate func convertMultiArrayToPixels(_ multiArray: MLMultiArray) -> [UInt8] {
  let height = multiArray.shape[1].intValue
  let width = multiArray.shape[2].intValue
  let size = Size<Int>(width: width, height: height)
  let heightStride = multiArray.strides[1].intValue
  let widthStride = multiArray.strides[2].intValue
  let ptr = UnsafeMutablePointer<Double>(OpaquePointer(multiArray.dataPointer))
  let count = size.width * size.height
  var pixels = [UInt8](repeating: 0, count: count)
  for y in 0 ..< height {
    for x in 0 ..< width {
      let value = ptr[y * heightStride + x * widthStride]
      let scaled = clamp(value * 255, min: 0, max: 255)
      pixels[y * width + x] = UInt8(exactly: scaled.rounded()) ?? 0
    }
  }
  return pixels
}
