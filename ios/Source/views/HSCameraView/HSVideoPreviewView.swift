import AVFoundation
import HSCameraUtils
import UIKit

class HSVideoPreviewView: UIView {
  private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
    let layer = AVCaptureVideoPreviewLayer(session: HSCameraManager.shared.captureSession)
    layer.videoGravity = .resizeAspect
    return layer
  }()

  public var resizeMode: HSResizeMode = .scaleAspectWidth {
    didSet {
      layoutSubviews()
    }
  }

  public var isPaused: Bool {
    get {
      return HSCameraManager.shared.captureSession.isRunning
    }
    set {
      newValue
        ? HSCameraManager.shared.stopPreview()
        : HSCameraManager.shared.startPreview()
    }
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    backgroundColor = .black
    layer.sublayers = nil
    layer.addSublayer(previewLayer)
    layoutSubviews()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard let videoResolution = HSCameraManager.shared.videoResolution else {
      return
    }
    resize(videoResolution: videoResolution)
  }

  internal func resize(videoResolution _: Size<Int>) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    defer { CATransaction.commit() }
    previewLayer.frame = CGRect(
      origin: .zero,
      size: frame.size
    )
  }

  public func focus(on point: CGPoint) {
    let focusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
    HSCameraManager.shared.focus(on: focusPoint)
  }
}
