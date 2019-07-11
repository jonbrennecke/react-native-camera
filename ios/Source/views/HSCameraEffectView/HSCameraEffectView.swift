import AVFoundation
import UIKit

@available(iOS 11.1, *)
@objc
class HSCameraEffectView: UIView {
  private lazy var effectLayer: CALayer = {
    HSEffectManager.shared.effectLayer
  }()

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    layer.sublayers = nil
    layer.addSublayer(effectLayer)
    layoutSubviews()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    effectLayer.frame = bounds
  }
}
