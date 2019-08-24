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
    guard let resolution = HSCameraManager.shared.videoResolution else {
      return
    }
    let originalSize = CGSize(width: resolution.width, height: resolution.height)
    let scale = scaleForResizing(originalSize, to: frame.size, resizeMode: resizeMode)
    previewLayer.frame = CGRect(
      origin: .zero,
      size: originalSize.applying(CGAffineTransform(scaleX: scale, y: scale))
    )
  }

  public func focus(on point: CGPoint) {
    let focusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
    HSCameraManager.shared.focus(on: focusPoint)
  }
}
