import AVFoundation
import UIKit

@available(iOS 11.1, *)
@objc
class HSCameraView: UIView {
  
  private enum PreviewView {
    case depth(HSDepthPreviewView)
    case video(HSVideoPreviewView)
  }
  
  private var previewView: PreviewView = .video(HSVideoPreviewView()) {
    didSet {
      switch previewView {
      case .depth(let view):
        subviews.forEach { $0.removeFromSuperview() }
        view.frame = bounds
        addSubview(view)
      case .video(let view):
        subviews.forEach { $0.removeFromSuperview() }
        view.frame = bounds
        addSubview(view)
      }
    }
  }
  
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
    switch previewView {
    case .depth(let view):
      view.frame = bounds
    case .video(let view):
      view.frame = bounds
    }
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
      switch newValue {
      case .depth, .portraitMode:
        HSEffectManager.shared.isPaused = true
        previewView = .depth(HSDepthPreviewView())
        HSEffectManager.shared.isPaused = false
      case .normal:
        HSEffectManager.shared.isPaused = true
        previewView = .video(HSVideoPreviewView())
      }
      HSEffectManager.shared.previewMode = newValue
    }
  }

  @objc
  public var resizeMode: HSResizeMode = .scaleAspectFill {
    didSet {
      switch previewView {
      case .depth(_):
        HSEffectManager.shared.resizeMode = resizeMode
      case .video(let view):
        view.resizeMode = resizeMode
      }
    }
  }
}
