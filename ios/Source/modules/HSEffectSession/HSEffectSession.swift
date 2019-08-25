import AVFoundation
import CoreGraphics
import HSCameraUtils
import MetalKit
import UIKit

@available(iOS 11.0, *)
@objc
class HSEffectSession: NSObject {
  private var depthDataObserver: HSCameraDepthDataObserver?

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
    let observer = HSCameraDepthDataObserver(delegate: self)
    HSCameraManager.shared.depthDataObservers.addObserver(observer)
    depthDataObserver = observer
  }

  deinit {
    if let observer = depthDataObserver {
      HSCameraManager.shared.depthDataObservers.removeObserver(observer)
    }
  }

  public var isPaused: Bool {
    get {
      return depthDataObserver?.isPaused ?? false
    }
    set {
      depthDataObserver?.isPaused = newValue
    }
  }

  // MARK: - Objective-C interface

  public var disparityPixelBuffer: HSPixelBuffer?

  public var videoPixelBuffer: HSPixelBuffer?
}

extension HSEffectSession: HSCameraManagerDepthDataDelegate {
  func cameraManagerDidOutput(disparityPixelBuffer: HSPixelBuffer) {
    self.disparityPixelBuffer = disparityPixelBuffer
  }

  func cameraManagerDidOutput(videoPixelBuffer: HSPixelBuffer) {
    self.videoPixelBuffer = videoPixelBuffer
  }
}
