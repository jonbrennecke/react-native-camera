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
  
  private let colorSpace = CGColorSpaceCreateDeviceGray()

  @objc(sharedInstance)
  public static let shared = HSEffectManager()
  
  private static let queue = DispatchQueue(label: "effect queue")

  @objc(applyEffectWithDepthData:)
  public func applyEffect(with depthData: AVDepthData) {
    HSEffectManager.queue.async {
      self.applyEffectOnBackgroundQueue(with: depthData)
    }
  }
  
  private func applyEffectOnBackgroundQueue(with originalDepthData: AVDepthData) {
    let depthData = originalDepthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
    let depthBuffer = depthData.depthDataMap
    CVPixelBufferLockBaseAddress(depthBuffer, .readOnly)
    
    let pixelSize = sizeOf(buffer: depthBuffer)
    let pixelBufferBytesPerRow = CVPixelBufferGetBytesPerRow(depthBuffer)
    let pixelBufferPtr = unsafeBitCast(CVPixelBufferGetBaseAddress(depthBuffer), to: UnsafeMutablePointer<Float32>.self)
    let ptrLength = Int(pixelSize.height) * pixelBufferBytesPerRow / MemoryLayout<Float32>.size + Int(pixelSize.width)
    let maxDepth = max(ptr: pixelBufferPtr, count: ptrLength)
    
    let bytesPerRow = Int(pixelSize.width) * MemoryLayout<UInt8>.size
    let dataByteLength = Int(pixelSize.height) * bytesPerRow
    
    guard
      let data = CFDataCreateMutable(kCFAllocatorDefault, dataByteLength),
      let bytes = CFDataGetMutableBytePtr(data)
      else {
        return
    }
    CFDataSetLength(data, dataByteLength)
    
    let byteIndex = { (x: Int, y: Int) -> Int in
      return (y * bytesPerRow) + x * MemoryLayout<UInt8>.size
    }
    
    let pixelBufferIndex = { (x: Int, y: Int) -> Int in
      return y * (pixelBufferBytesPerRow / MemoryLayout<Float32>.size) + x
    }
    
    for y in 0 ..< Int(pixelSize.height) {
      for x in 0 ..< Int(pixelSize.width) {
        let value = pixelBufferPtr[pixelBufferIndex(x, y)]
        let depth = UInt8((min(value, maxDepth) / maxDepth) * 255)
        let i = byteIndex(x, y)
        bytes[i] = depth
      }
    }

    updateImage(pixelSize: pixelSize, data: data, byteSize: MemoryLayout<UInt8>.size)
    CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly)
  }

  private func updateImage(pixelSize: CGSize, data: CFData, byteSize: Int) {
    guard let provider = CGDataProvider(data: data) else {
      return
    }
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
    let image = CGImage(
      width: Int(pixelSize.width),
      height: Int(pixelSize.height),
      bitsPerComponent: Int(8),
      bitsPerPixel: byteSize * 8,
      bytesPerRow: Int(pixelSize.width) * byteSize,
      space: colorSpace,
      bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: true,
      intent: .defaultIntent
    )
    DispatchQueue.main.async {
      self.effectLayer.contents = image
    }
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
