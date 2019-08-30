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

  internal func makeEffectImage(blurAperture: Float = 2.5, size: CGSize, resizeMode: HSResizeMode) -> CIImage? {
    return autoreleasepool {
      guard
        let disparityPixelBuffer = disparityPixelBuffer,
        let videoPixelBuffer = videoPixelBuffer
      else {
        return nil
      }
      let scale = Float(scaleForResizing(videoPixelBuffer.size.cgSize(), to: size, resizeMode: resizeMode))
      guard let effectImage = depthBlurEffect.makeEffectImage(
        previewMode: previewMode == .depth ? .depth : .portraitBlur,
        disparityPixelBuffer: disparityPixelBuffer,
        videoPixelBuffer: videoPixelBuffer,
        calibrationData: calibrationData,
        blurAperture: blurAperture,
        scale: scale,
        qualityFactor: 0.1
      ) else {
        return nil
      }
      let scaledSize = Size<Int>(
        width: Int((Float(videoPixelBuffer.size.width) * scale).rounded()),
        height: Int((Float(videoPixelBuffer.size.height) * scale).rounded())
      )
      let yDiff = CGFloat(scaledSize.height) - CGFloat(size.height)
      let xDiff = CGFloat(scaledSize.width) - CGFloat(size.width)
      return effectImage
        .transformed(by: CGAffineTransform(translationX: -xDiff * 0.5, y: -yDiff))
    }
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

  public var calibrationData: AVCameraCalibrationData?

  public var videoPixelBuffer: HSPixelBuffer?

  public var focusPoint: CGPoint?
}

extension HSEffectSession: HSCameraManagerDepthDataDelegate {
  func cameraManagerDidOutput(disparityPixelBuffer: HSPixelBuffer, calibrationData: AVCameraCalibrationData?) {
    self.disparityPixelBuffer = disparityPixelBuffer
    self.calibrationData = calibrationData
  }

  func cameraManagerDidOutput(videoPixelBuffer: HSPixelBuffer) {
    self.videoPixelBuffer = videoPixelBuffer
  }

  func cameraManagerDidFocus(on focusPoint: CGPoint) {
    self.focusPoint = focusPoint
  }
}
