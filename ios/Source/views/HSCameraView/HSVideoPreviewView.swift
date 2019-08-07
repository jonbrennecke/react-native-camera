import AVFoundation
import UIKit

class HSVideoPreviewView: UIView {
  private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
    let layer = AVCaptureVideoPreviewLayer(session: HSCameraManager.shared.captureSession)
    layer.videoGravity = .resizeAspectFill
    return layer
  }()

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
