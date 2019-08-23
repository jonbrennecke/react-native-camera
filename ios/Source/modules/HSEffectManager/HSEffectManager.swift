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

  public var previewMode: HSEffectPreviewMode = .portraitMode

  internal func makeEffectImage(blurAperture: Float = 0, outputSize: CGSize, resizeMode: HSResizeMode) -> CIImage? {
    guard
      let disparityPixelBuffer = disparityPixelBuffer,
      let videoPixelBuffer = videoPixelBuffer
    else {
      return nil
    }
    return depthBlurEffect.makeEffectImage(
      previewMode: previewMode == .depth ? .depth : .portraitBlur,
      disparityPixelBuffer: disparityPixelBuffer,
      videoPixelBuffer: videoPixelBuffer,
      outputSize: outputSize,
      resizeMode: resizeMode,
      aperture: blurAperture
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

  public var disparityPixelBuffer: HSPixelBuffer?

  public var videoPixelBuffer: HSPixelBuffer?
}

extension HSEffectManager: HSCameraManagerDepthDataDelegate {
  func cameraManagerDidOutput(disparityPixelBuffer: HSPixelBuffer) {
    self.disparityPixelBuffer = disparityPixelBuffer
  }

  func cameraManagerDidOutput(videoPixelBuffer: HSPixelBuffer) {
    self.videoPixelBuffer = videoPixelBuffer
  }
}
