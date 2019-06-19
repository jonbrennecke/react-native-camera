import AVFoundation
import CoreGraphics
import UIKit

@available(iOS 11.0, *)
@objc
class HSEffectManager: NSObject {
  private struct Pixel {
    var a: UInt8
    var r: UInt8
    var g: UInt8
    var b: UInt8

    static let transparent = Pixel(a: 0, r: 0, g: 0, b: 0)
  }

  internal let effectLayer = CALayer()
  
  private let colorSpace = CGColorSpaceCreateDeviceRGB()

  private var image: CGImage?

  @objc(sharedInstance)
  public static let shared = HSEffectManager()

  @objc(applyEffectWithDepthData:)
  public func applyEffect(with originalDepthData: AVDepthData) {
    let depthData = originalDepthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
    let depthBuffer = depthData.depthDataMap
    CVPixelBufferLockBaseAddress(depthBuffer, .readOnly)
    let size = sizeOf(buffer: depthBuffer)
    let length = Int(size.width * size.height)

//    guard
//      let data = CFDataCreateMutable(kCFAllocatorDefault, length),
//      let bytes = CFDataGetMutableBytePtr(data)
//    else {
//      return
//    }
//    CFDataSetLength(data, length)

    let bytesPerRow = CVPixelBufferGetBytesPerRow(depthBuffer)
    let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthBuffer), to: UnsafeMutablePointer<Float32>.self)
    let maxDepth = max(data: floatBuffer, count: Int(size.height) * bytesPerRow / 4 + Int(size.width))
    var pixels = Array<Pixel>(repeating: .transparent, count: length)

    for x in 0 ..< Int(size.width) {
      for y in 0 ..< Int(size.height) {
        let arrayIndex = (y * Int(size.width)) + x
        let bufferIndex = y * (bytesPerRow / 4) + x
        let value = floatBuffer[bufferIndex]
        let depth = UInt8((min(value, maxDepth) / maxDepth) * 255)
        pixels[arrayIndex] = Pixel(a: 255, r: depth, g: depth, b: depth)
      }
    }

    let data = NSData(bytes: &pixels, length: length * MemoryLayout<Int>.size)
    updateImage(size: size, data: data)
    CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly)
  }

  private func updateImage(size: CGSize, data: CFData) {
    guard let provider = CGDataProvider(data: data) else {
      return
    }
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
//    let imageSource = CGImageSourceCreateWithDataProvider(provider, nil)
    image = CGImage(
      width: Int(size.width),
      height: Int(size.height),
      bitsPerComponent: Int(8),
      bitsPerPixel: Int(32),
      bytesPerRow: Int(size.width) * 4, // Int(MemoryLayout<Int>.size * 4),
      space: colorSpace,
      bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: true,
      intent: .defaultIntent
    )
    effectLayer.contents = image
    effectLayer.contentsGravity = .resizeAspectFill
    effectLayer.isGeometryFlipped = true
  }
}

fileprivate func max(data: UnsafeMutablePointer<Float32>, count: Int) -> Float32 {
  var currentMax = Float32(0)
  for i in 0 ..< count {
    let value = data[i]
    if value > currentMax {
      currentMax = value
    }
  }
  return currentMax
}

fileprivate func sizeOf(buffer: CVPixelBuffer) -> CGSize {
  let width = CVPixelBufferGetWidth(buffer)
  let height = CVPixelBufferGetHeight(buffer)
  return CGSize(width: width, height: height)
}
