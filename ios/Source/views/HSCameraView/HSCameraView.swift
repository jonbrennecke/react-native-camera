import AVFoundation
import UIKit

@available(iOS 11.1, *)
@objc
class HSCameraView: UIView {
  private enum PreviewView {
    case effect(HSEffectPreviewView)
    case video(HSVideoPreviewView)
  }

  private var previewView: PreviewView = .video(HSVideoPreviewView()) {
    didSet {
      switch previewView {
      case let .effect(view):
        subviews.forEach { $0.removeFromSuperview() }
        view.frame = bounds
        addSubview(view)
      case let .video(view):
        subviews.forEach { $0.removeFromSuperview() }
        view.frame = bounds
        addSubview(view)
      }
    }
  }

  init() {
    super.init(frame: .zero)
    previewMode = .portraitMode
    HSCameraManager.shared.playbackDelegate = self
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
    case let .effect(view):
      view.frame = bounds
    case let .video(view):
      view.frame = bounds
    }
  }

  // MARK: - objc interface

  @objc(focusOnPoint:)
  public func focus(on point: CGPoint) {
    switch previewView {
    case let .effect(view):
      view.focus(on: point)
    case let .video(view):
      view.focus(on: point)
    }
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
        previewView = .effect(HSEffectPreviewView())
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
      case let .effect(view):
        view.resizeMode = resizeMode
      case let .video(view):
        view.resizeMode = resizeMode
      }
    }
  }

  @objc
  public var blurAperture: Float {
    get {
      if case let .effect(view) = previewView {
        return view.blurAperture
      }
      return 0
    }
    set {
      if case let .effect(view) = previewView {
        view.blurAperture = newValue
      }
    }
  }
}

extension HSCameraView: HSCameraManagerPlaybackDelegate {
  func cameraManagerDidBeginCapture() {}

  func cameraManagerDidEndCapture() {}

  func cameraManagerDidBeginPreview() {
    DispatchQueue.main.async { [weak self] in
      guard let strongSelf = self else { return }
      switch strongSelf.previewView {
      case let .effect(view):
        view.layoutSubviews()
      case let .video(view):
        view.layoutSubviews()
      }
    }
  }

  func cameraManagerDidEndPreview() {}
}
