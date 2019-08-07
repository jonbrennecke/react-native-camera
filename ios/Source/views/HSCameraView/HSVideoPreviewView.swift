import AVFoundation
import UIKit

class HSVideoPreviewView: UIView {
  private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
    AVCaptureVideoPreviewLayer(session: HSCameraManager.shared.captureSession)
  }()

  public var resizeMode: HSResizeMode = .scaleAspectWidth {
    didSet {
      previewLayer.videoGravity = resizeMode.videoGravity
    }
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    layer.sublayers = nil
    layer.addSublayer(previewLayer)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    previewLayer.frame = bounds
  }
}
