import AVFoundation
import UIKit

@available(iOS 11.1, *)
@objc
class HSCameraView: UIView {
  private lazy var depthPreviewView = HSDepthPreviewView()
  private lazy var videoPreviewView = HSVideoPreviewView()

  init() {
    super.init(frame: .zero)
    previewMode = .portraitMode
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    layoutSubviews()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    depthPreviewView.frame = bounds
    videoPreviewView.frame = bounds
  }

  // MARK: - objc interface

  @objc(focusOnPoint:)
  public func focus(on _: CGPoint) {
//    TODO:
//    let focusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
//    HSCameraManager.shared.focus(on: focusPoint)
  }

  @objc
  public var cameraPosition: AVCaptureDevice.Position {
    get {
      return HSCameraManager.shared.position
    }
    set {
      HSCameraManager.shared.position = newValue
    }
  }

  @objc
  public var previewMode: HSEffectPreviewMode {
    get {
      return HSEffectManager.shared.previewMode
    }
    set {
      if newValue == .normal {
        HSEffectManager.shared.stopDisplayLink()
        subviews.forEach { $0.removeFromSuperview() }
        videoPreviewView.frame = bounds
        addSubview(videoPreviewView)
      } else {
        HSEffectManager.shared.startDisplayLink()
        subviews.forEach { $0.removeFromSuperview() }
        depthPreviewView.frame = bounds
        addSubview(depthPreviewView)
      }
      HSEffectManager.shared.previewMode = newValue
    }
  }
  
  @objc
  public var resizeMode: HSResizeMode = .scaleAspectFill {
    didSet {
      HSEffectManager.shared.resizeMode = resizeMode
      videoPreviewView.resizeMode = resizeMode
    }
  }
}
