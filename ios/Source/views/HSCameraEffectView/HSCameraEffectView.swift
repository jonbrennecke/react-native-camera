import AVFoundation
import UIKit

@available(iOS 11.1, *)
@objc
class HSCameraEffectView: UIView {
  
  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    addSubview(HSEffectManager.shared.effectView)
    layoutSubviews()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    HSEffectManager.shared.effectView.frame = bounds
  }
}
