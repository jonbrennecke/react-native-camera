import MetalKit
import UIKit

class HSDepthPreviewView: UIView {
  private var effectView: MTKView {
    return HSEffectManager.shared.effectView
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    layer.backgroundColor = UIColor.black.cgColor
    addSubview(effectView)
    layoutSubviews()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    effectView.frame = bounds
    effectView.drawableSize = effectView.frame.size
  }
}
