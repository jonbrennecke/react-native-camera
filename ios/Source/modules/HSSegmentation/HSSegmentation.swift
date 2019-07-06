import CoreML
import HSCameraUtils

public class HSSegmentation {
  private let model: HSSegmentationModel

  init(model: HSSegmentationModel) {
    self.model = model
  }

  public func runSegmentation(
    colorBuffer: HSPixelBuffer,
    depthBuffer: HSPixelBuffer
  ) throws -> HSPixelBuffer? {
    let input = HSSegmentationModelInput(
      color_image_input: colorBuffer.buffer,
      depth_image_input: depthBuffer.buffer
    )
    let output = try model.prediction(input: input)

    let multiArray = output.segmentation_image_output
    let height = multiArray.shape[1].intValue
    let width = multiArray.shape[2].intValue
    let size = Size<Int>(width: width, height: height)

    let pixels: [Double] = convert(multiArray: multiArray)
    var integers = pixels.map { pixel -> UInt8 in
//      let scaled = (value - min) * 255 / (max - min)
//      let pixel = clamp(scaled, min: 0, max: 255)
      return UInt8(exactly: pixel.rounded())!
    }

//    guard let buffer = createBuffer(with: &integers, size: size, bytesPerRow:  bufferInfo: .grayScaleUInt8) else {
//      return nil
//    }
//    return HSPixelBuffer(pixelBuffer: buffer)
    return nil
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
//      let scaled = (value - min) * T(255) / (max - min)
//      let pixel = clamp(scaled, min: T(0), max: T(255)).toUInt8
      pixels[y * width + x] = value
    }
  }
  return pixels
}
