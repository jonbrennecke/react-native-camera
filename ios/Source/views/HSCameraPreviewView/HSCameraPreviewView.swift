import UIKit

@available(iOS 10.0, *)
@objc
class HSCameraPreviewView: UIView {
  private var previewLayer: CALayer {
    return HSCameraManager.shared.previewLayer
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    layer.sublayers = nil
    layer.addSublayer(previewLayer)
    layoutSubviews()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    previewLayer.frame = bounds
  }
}
