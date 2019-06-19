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

  internal lazy var effectLayer: CALayer = {
    let layer = CALayer()
    layer.contentsGravity = .resizeAspectFill
    layer.isGeometryFlipped = true
    return layer
  }()
  
  private let colorSpace = CGColorSpaceCreateDeviceRGB()

  @objc(sharedInstance)
  public static let shared = HSEffectManager()

  @objc(applyEffectWithDepthData:)
  public func applyEffect(with originalDepthData: AVDepthData) {
    let depthData = originalDepthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
    let depthBuffer = depthData.depthDataMap
    CVPixelBufferLockBaseAddress(depthBuffer, .readOnly)
    
    let pixelSize = sizeOf(buffer: depthBuffer)
    let pixelBufferBytesPerRow = CVPixelBufferGetBytesPerRow(depthBuffer)
    let ptr = unsafeBitCast(CVPixelBufferGetBaseAddress(depthBuffer), to: UnsafeMutablePointer<Float32>.self)
    let ptrLength = Int(pixelSize.height) * pixelBufferBytesPerRow / MemoryLayout<Float32>.size + Int(pixelSize.width)
    let maxDepth = max(ptr: ptr, count: ptrLength)
    
    let bytesPerRow = Int(pixelSize.width) * MemoryLayout<Float32>.size
    let dataByteLength = Int(pixelSize.height) * bytesPerRow
    
    guard
      let data = CFDataCreateMutable(kCFAllocatorDefault, dataByteLength),
      let bytes = CFDataGetMutableBytePtr(data)
      else {
        return
    }
    CFDataSetLength(data, dataByteLength)
    
    let byteIndex = { (x: Int, y: Int) -> Int in
      return (y * bytesPerRow) + x * MemoryLayout<Float32>.size
    }
    
    let pixelBufferIndex = { (x: Int, y: Int) -> Int in
      return y * (pixelBufferBytesPerRow / MemoryLayout<Float32>.size) + x
    }

    for y in 0 ..< Int(pixelSize.height) {
      for x in 0 ..< Int(pixelSize.width) {
        let value = ptr[pixelBufferIndex(x, y)]
        let depth = UInt8((min(value, maxDepth) / maxDepth) * 255)
        
        // byte value at index
        let i = byteIndex(x, y)
        bytes[i] = 255
        bytes[i + 1] = depth
        bytes[i + 2] = depth
        bytes[i + 3] = depth
      }
    }

    updateImage(pixelSize: pixelSize, data: data)
    CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly)
  }

  private func updateImage(pixelSize: CGSize, data: CFData) {
    guard let provider = CGDataProvider(data: data) else {
      return
    }
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
    effectLayer.contents = CGImage(
      width: Int(pixelSize.width),
      height: Int(pixelSize.height),
      bitsPerComponent: Int(8),
      bitsPerPixel: MemoryLayout<Float32>.size * 8,
      bytesPerRow: Int(pixelSize.width) * MemoryLayout<Float32>.size,
      space: colorSpace,
      bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: true,
      intent: .defaultIntent
    )
  }
}

fileprivate func max(ptr: UnsafeMutablePointer<Float32>, count: Int) -> Float32 {
  var currentMax = Float32(0)
  for i in 0 ..< count {
    let value = ptr[i]
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
