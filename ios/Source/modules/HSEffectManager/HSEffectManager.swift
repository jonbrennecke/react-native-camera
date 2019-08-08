import AVFoundation
import CoreGraphics
import HSCameraUtils
import MetalKit
import UIKit

@available(iOS 11.0, *)
@objc
class HSEffectManager: NSObject {
  private let printDebugLog = true
  private lazy var depthBlurEffect = HSDepthBlurEffect()

  public var previewMode: HSEffectPreviewMode = .depth
  
  internal func makeEffectImage() -> CIImage? {
    guard
      let depthData = depthData,
      let videoSampleBuffer = videoSampleBuffer,
      let videoPixelBuffer = HSPixelBuffer(sampleBuffer: videoSampleBuffer)
    else {
      return nil
    }
    let isDepth = [kCVPixelFormatType_DepthFloat16, kCVPixelFormatType_DepthFloat32].contains(depthData.depthDataType)
    let disparityData = isDepth ? depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat16) : depthData
    let disparityPixelBuffer = HSPixelBuffer(depthData: disparityData)
    return depthBlurEffect.makeEffectImage(
      previewMode: previewMode == .depth ? .depth : .portraitBlur,
      qualityMode: .previewQuality,
      disparityPixelBuffer: disparityPixelBuffer,
      videoPixelBuffer: videoPixelBuffer,
      aperture: HSCameraManager.shared.aperture
    )
  }
  
  override init() {
    super.init()
    HSCameraManager.shared.depthDelegate = self
  }

  public var isPaused: Bool = false {
    didSet {
      if isPaused {
        HSCameraManager.shared.depthDelegate = nil
      } else {
        HSCameraManager.shared.depthDelegate = self
      }
    }
  }

  // MARK: - Objective-C interface

  @objc(sharedInstance)
  public static let shared = HSEffectManager()

  @objc
  public var depthData: AVDepthData?

  @objc
  public var videoSampleBuffer: CMSampleBuffer?
}

extension HSEffectManager: HSCameraManagerDepthDataDelegate {
  func cameraManagerDidOutput(depthData: AVDepthData) {
    self.depthData = depthData
  }

  func cameraManagerDidOutput(videoSampleBuffer: CMSampleBuffer) {
    self.videoSampleBuffer = videoSampleBuffer
  }
}
