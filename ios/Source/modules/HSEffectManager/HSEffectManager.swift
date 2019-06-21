import AVFoundation
import CoreGraphics
import UIKit

@available(iOS 11.0, *)
@objc
class HSEffectManager: NSObject {
  internal lazy var effectLayer: CALayer = {
    let layer = CALayer()
    layer.contentsGravity = .resizeAspectFill
    layer.isGeometryFlipped = false
//    layer.opacity = 0.9
    return layer
  }()

  private let context = CIContext(options: nil)
  private let colorSpace = CGColorSpaceCreateDeviceGray()
  private let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).union(CGBitmapInfo())

  @objc(sharedInstance)
  public static let shared = HSEffectManager()

  private static let queue = DispatchQueue(label: "effect queue")

  @objc(applyEffectWithDepthData:videoData:)
  public func applyEffect(with depthData: AVDepthData, videoData: CMSampleBuffer) {
    HSEffectManager.queue.async {
      self.applyEffectOnBackgroundQueue(with: depthData, videoData: videoData)
    }
  }

  private func applyEffectOnBackgroundQueue(with originalDepthData: AVDepthData, videoData: CMSampleBuffer) {
    let depthData = originalDepthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
    let depthBuffer = depthData.depthDataMap
    CVPixelBufferLockBaseAddress(depthBuffer, .readOnly)

    let pixelSize: Size<Int> = pixelSizeOf(buffer: depthBuffer)
    let pixelBufferBytesPerRow = CVPixelBufferGetBytesPerRow(depthBuffer) / MemoryLayout<Float32>.size
    let pixelBufferPtr = unsafeBitCast(CVPixelBufferGetBaseAddress(depthBuffer), to: UnsafeMutablePointer<Float32>.self)

    let ptrLength = pixelSize.height * pixelBufferBytesPerRow + pixelSize.width
    let (min: minDepth, max: maxDepth) = minMax(ptr: pixelBufferPtr, count: ptrLength)

    let length = pixelSize.width * pixelSize.height
    var pixelValues = [UInt8](repeating: 0, count: length)

//    let partialDerivativeX = { (x: Int, y: Int) -> Float32 in
//      symmetricDerivative(x, 8) { x in
//        let pixel = pixelBufferPtr[pixelBufferIndex(clamp(x, min: 0, max: pixelSize.width), y)]
//        return normalize(pixel, min: minDepth, max: maxDepth)
//      }
//    }
//
//    let partialDerivativeY = { (x: Int, y: Int) -> Float32 in
//      symmetricDerivative(y, 8) { y in
//        let pixel = pixelBufferPtr[pixelBufferIndex(x, clamp(y, min: 0, max: pixelSize.height))]
//        return normalize(pixel, min: minDepth, max: maxDepth)
//      }
//    }
//
//    let derivative = { (x: Int, y: Int) -> Float32 in
//      let pdX = partialDerivativeX(x, y)
//      let pdY = partialDerivativeY(x, y)
//      return abs((pdX - pdY) / 2)
//    })
    
    // TODO: find average of area
    let depthAtRegionOfInterest = { () -> Float32 in
      let center = Index(x: pixelSize.width / 2, y: pixelSize.height / 2)
      let pixelBufferIndex = arrayIndex(for: pixelBufferBytesPerRow, x: center.x, y: center.y)
      let depthValue = pixelBufferPtr[pixelBufferIndex]
      if depthValue.isNaN {
        return 0
      }
      return normalize(depthValue, min: minDepth, max: maxDepth)
    }
    
    let regionDepth = depthAtRegionOfInterest()
    let regionRange = regionDepth-0.15 ... regionDepth+0.15

    loop(size: pixelSize) { x, y in
      let pixelBufferIndex = arrayIndex(for: pixelBufferBytesPerRow, x: x, y: y)
      let depthValue = pixelBufferPtr[pixelBufferIndex]
      if depthValue.isNaN {
        pixelValues[arrayIndex(for: pixelSize.width, x: x, y: y)] = 0
        return
      }
      let depth = normalize(depthValue, min: minDepth, max: maxDepth)
      if depth < regionRange.lowerBound {
        pixelValues[arrayIndex(for: pixelSize.width, x: x, y: y)] = 0
        return
      }
      else if depth > regionRange.upperBound {
        pixelValues[arrayIndex(for: pixelSize.width, x: x, y: y)] = 255
        return
      }
      let adjustedDepth = normalize(depth, min: regionRange.lowerBound, max: regionRange.upperBound)
      let depthPixelValue = UInt8(adjustedDepth * 255)
      pixelValues[arrayIndex(for: pixelSize.width, x: x, y: y)] = depthPixelValue
    }

    CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly)

    if let image = createImage(
      pixelValues: pixelValues,
      imageSize: pixelSize,
      colorSpace: colorSpace,
      bitmapInfo: bitmapInfo
    ) {
      applyFilters(image: image)
    }
  }

  func applyFilters(image: CGImage) {
    let ciImage = CIImage(cgImage: image)
    let blurRadius = 2
    let flipTransform = CGAffineTransform(scaleX: -1, y: 1)
    let ciImageWithContrast = ciImage
      .clampedToExtent()
      .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": blurRadius])
      .cropped(to: ciImage.extent)
      .applyingFilter("CIAffineTransform", parameters: ["inputTransform": flipTransform])
    
    guard let cgImage = context.createCGImage(ciImageWithContrast, from: ciImageWithContrast.extent) else {
      return
    }
    DispatchQueue.main.async {
      self.effectLayer.contents = cgImage
    }
  }
}

fileprivate func minMax(ptr: UnsafeMutablePointer<Float32>, count: Int) -> (min: Float32, max: Float32) {
  var minValue: Float = .greatestFiniteMagnitude
  var maxValue: Float = .leastNormalMagnitude
  for i in 0 ..< count {
    let value = ptr[i]
    if value.isNaN {
      continue
    }
    if value < minValue {
      minValue = value
    }
    if value > maxValue {
      maxValue = value
    }
  }
  return (min: minValue, max: maxValue)
}

// map 2d data to a 1d index
fileprivate func arrayIndex(for width: Int, x: Int, y: Int) -> Int {
  return y * width + x
}

fileprivate func pixelSizeOf<T: Numeric>(buffer: CVPixelBuffer) -> Size<T> {
  let width = CVPixelBufferGetWidth(buffer)
  let height = CVPixelBufferGetHeight(buffer)
  return Size<T>(width: T(exactly: width)!, height: T(exactly: height)!)
}

fileprivate func loop(size: Size<Int>, _ callback: (Int, Int) -> Void) {
  for x in 0 ..< size.width {
    for y in 0 ..< size.height {
      callback(x, y)
    }
  }
}

// MARK: - math functions

internal func normalize<T: FloatingPoint>(_ x: T, min: T, max: T) -> T {
  return (x - min) / (max - min)
}

internal func clamp<T: FloatingPoint>(_ x: T, min xMin: T, max xMax: T) -> T {
  if x.isNaN {
    return xMin
  }
  return max(min(x, xMax), xMin)
}

internal func clamp<T: SignedInteger>(_ x: T, min xMin: T, max xMax: T) -> T {
  return max(min(x, xMax), xMin)
}

internal func symmetricDerivative(_ x: Int, _ h: Int, _ f: (Int) -> Float32) -> Float32 {
  return (f(x + h) - f(x - h)) / 2 * Float32(h)
}

internal func symmetricSecondDerivative(_ x: Int, _ h: Int, _ f: (Int) -> Float32) -> Float32 {
  return (f(x + h) - 2 * f(x) + f(x - h)) / Float32(h * h)
}
