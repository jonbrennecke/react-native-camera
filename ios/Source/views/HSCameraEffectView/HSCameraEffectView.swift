import AVFoundation
import UIKit

@available(iOS 11.1, *)
@objc
class HSCameraEffectView: UIView {
  private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
    let layer = AVCaptureVideoPreviewLayer(session: HSCameraManager.shared.captureSession)
    layer.videoGravity = .resizeAspectFill
    return layer
  }()

  private lazy var effectLayer: CALayer = {
    HSEffectManager.shared.effectLayer
  }()

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    layer.sublayers = nil
    layer.addSublayer(previewLayer)
    layer.addSublayer(effectLayer)
    previewLayer.zPosition = 0
    effectLayer.zPosition = 1
    layoutSubviews()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    previewLayer.frame = bounds
    effectLayer.frame = bounds
  }
}
