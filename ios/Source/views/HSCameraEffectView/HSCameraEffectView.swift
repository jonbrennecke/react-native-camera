import AVFoundation
import UIKit
import MetalKit

@available(iOS 11.1, *)
@objc
class HSCameraEffectView: UIView {
  
  private var effectView: MTKView {
    return HSEffectManager.shared.effectView
  }
  
  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    addSubview(effectView)
    layoutSubviews()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    effectView.frame = bounds
  }
}
