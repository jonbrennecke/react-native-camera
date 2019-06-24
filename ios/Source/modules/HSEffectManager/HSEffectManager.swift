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
    return layer
  }()

  private let context = CIContext(options: nil)
  private let colorSpace = CGColorSpaceCreateDeviceGray()
  private let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).union(CGBitmapInfo())

  @objc(sharedInstance)
  public static let shared = HSEffectManager()

  private static let queue = DispatchQueue(label: "effect queue")

  @objc(applyEffectWithDepthData:videoData:)
  public func applyEffect(with depthData: AVDepthData, videoSampleBuffer: CMSampleBuffer) {
    HSEffectManager.queue.async {
      self.applyEffectOnBackgroundQueue(with: depthData, videoSampleBuffer: videoSampleBuffer)
    }
  }

  private func applyEffectOnBackgroundQueue(with originalDepthData: AVDepthData, videoSampleBuffer: CMSampleBuffer) {
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

    // TODO: find average of area + use face tracking to estimate subject
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
    let regionRange = regionDepth - 0.15 ... regionDepth + 0.15
    
    let depthAtIndex = { (x: Int, y: Int) -> Float32 in
      let pixelBufferIndex = arrayIndex(for: pixelBufferBytesPerRow, x: x, y: y)
      return pixelBufferPtr[pixelBufferIndex]
    }
    
    let setPixel = { (x: Int, y: Int, value: UInt8) -> Void in
      pixelValues[arrayIndex(for: pixelSize.width, x: x, y: y)] = value
    }

    loop(size: pixelSize) { x, y in
      let depthValue = depthAtIndex(x, y)
      if depthValue.isNaN {
        // handle unknown values; this is due to the distance between the infrared sensor and receiver
        for i in stride(from: x, to: x - 25, by: -1) {
          let depthValue = depthAtIndex(i, y)
          if depthValue.isNaN {
            continue;
          }
          let depth = normalize(depthValue, min: minDepth, max: maxDepth)
          if depth < regionRange.lowerBound {
            setPixel(x, y, 0)
            return
          }
          let adjustedDepth = normalize(depth, min: regionRange.lowerBound, max: regionRange.upperBound)
          let depthPixelValue = UInt8(adjustedDepth * 255)
          setPixel(x, y, depthPixelValue)
          return
        }
        
        setPixel(x, y, 0)
        return
      }
      let depth = normalize(depthValue, min: minDepth, max: maxDepth)
      if depth < regionRange.lowerBound {
        setPixel(x, y, 0)
        return
      }
      if depth > regionRange.upperBound {
        setPixel(x, y, 255)
        return
      }
      let adjustedDepth = normalize(depth, min: regionRange.lowerBound, max: regionRange.upperBound)
      let depthPixelValue = UInt8(adjustedDepth * 255)
      setPixel(x, y, depthPixelValue)
    }

    CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly)

    if
      let depthImage = createCIImage(
        pixelValues: pixelValues,
        imageSize: pixelSize,
        colorSpace: colorSpace,
        bitmapInfo: bitmapInfo
      ),
      let foregroundImage = createCIImage(with: videoSampleBuffer) {
      let maskScaleFactor = Float(foregroundImage.extent.width) / Float(pixelSize.width)
      let maskImage = createMask(depthImage: depthImage, scale: maskScaleFactor)
      let backgroundImage = CIImage(color: CIColor(red: 1, green: 0, blue: 0))
        .cropped(to: foregroundImage.extent)
      applyMask(foreground: foregroundImage, background: backgroundImage, mask: maskImage)
    }
  }

  func createMask(depthImage: CIImage, scale: Float) -> CIImage {
    let blurRadius = 3
    return depthImage
      .clampedToExtent()
      .applyingFilter("CINoiseReduction", parameters: ["inputNoiseLevel": 1, "inputSharpness": 0.4])
      .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": blurRadius])
      .cropped(to: depthImage.extent)
      .applyingFilter("CILanczosScaleTransform", parameters: ["inputScale": scale])
  }

  func applyMask(foreground foregroundImage: CIImage, background backgroundImage: CIImage, mask maskImage: CIImage) {
    let flipTransform = CGAffineTransform(scaleX: -1, y: 1)
//    let parameters = ["inputMaskImage": maskImage, "inputBackgroundImage": backgroundImage]
    let displayImage = maskImage
//      .applyingFilter("CIBlendWithMask", parameters: parameters)
      .applyingFilter("CIAffineTransform", parameters: ["inputTransform": flipTransform])

    guard let cgImage = context.createCGImage(displayImage, from: displayImage.extent) else {
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
