import AVFoundation
import ImageUtils
import UIKit

class HSVideoPreviewView: UIView {
  private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
    let layer = AVCaptureVideoPreviewLayer(session: HSCameraManager.shared.captureSession)
    layer.videoGravity = .resizeAspectFill
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
    resize()
  }

  internal func resize() {
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
