import AVFoundation
import HSCameraUtils
import UIKit

@available(iOS 11.1, *)
@objc
class HSCameraView: UIView {
  private enum PreviewView {
    case effect(HSEffectPreviewView)
    case video(HSVideoPreviewView)
  }

  private var resolutionObserver: HSCameraResolutionObserver?

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
    let observer = HSCameraResolutionObserver(delegate: self)
    HSCameraManager.shared.resolutionObservers.addObserver(observer)
    resolutionObserver = observer
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    if let observer = resolutionObserver {
      HSCameraManager.shared.resolutionObservers.removeObserver(observer)
    }
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    HSCameraManager.shared.setupCameraCaptureSession()
    HSCameraManager.shared.startPreview()
    layoutSubviews()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    switch previewView {
    case let .effect(view):
      view.frame = bounds
      view.layoutSubviews()
    case let .video(view):
      view.frame = bounds
      view.layoutSubviews()
    }
  }

  // MARK: - objc interface

  @objc
  public var isPaused: Bool = false {
    didSet {
      switch previewView {
      case let .effect(view):
        view.isPaused = isPaused
      case let .video(view):
        view.isPaused = isPaused
      }
    }
  }

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
  public func setCameraPosition(_ position: AVCaptureDevice.Position) {
    HSCameraManager.shared.setPosition(position)
  }

  @objc
  public func setResolutionPreset(_ resolutionPrest: HSCameraResolutionPreset) {
    HSCameraManager.shared.setResolutionPreset(resolutionPrest)
  }

  @objc
  public func setPreviewMode(_ previewMode: HSEffectPreviewMode) {
    switch previewMode {
    case .depth, .portraitMode:
      HSCameraManager.shared.setDepthEnabled(true)
      // TODO: don't recreate the preview view if we already have one
      let view = HSEffectPreviewView()
      view.effectSession.previewMode = previewMode
      view.blurAperture = blurAperture
      view.resizeMode = resizeMode
      previewView = .effect(view)
    default:
      HSCameraManager.shared.setDepthEnabled(false)
      previewView = .video(HSVideoPreviewView())
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
  public var blurAperture: Float = 2.4 {
    didSet {
      if case let .effect(view) = previewView {
        view.blurAperture = blurAperture
      }
    }
  }

  @objc
  public var watermarkImageNameWithExtension: String? {
    didSet {
      if case let .effect(view) = previewView {
        guard let fileName = watermarkImageNameWithExtension else {
          view.watermarkProperties = nil
          return
        }
        view.watermarkProperties = HSDepthBlurEffect.WatermarkProperties(
          fileName: fileName, fileExtension: "", scale: 0.45
        )
      }
    }
  }
}

@available(iOS 11.1, *)
extension HSCameraView: HSCameraManagerResolutionDelegate {
  func cameraManagerDidChange(videoResolution _: Size<Int>) {
    DispatchQueue.main.async { [weak self] in
      self?.layoutSubviews()
    }
  }

  func cameraManagerDidChange(depthResolution _: Size<Int>) {
    DispatchQueue.main.async { [weak self] in
      self?.layoutSubviews()
    }
  }
}
