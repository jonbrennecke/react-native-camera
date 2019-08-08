import MetalKit
import UIKit

class HSEffectPreviewView: UIView {
  private lazy var effectView: HSMetalEffectView = {
    return HSMetalEffectView(effectManager: HSEffectManager.shared)
  }()
  
  public var resizeMode: HSResizeMode {
    get {
      return effectView.resizeMode
    }
    set {
      effectView.resizeMode = resizeMode
    }
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

  public func focus(on point: CGPoint) {
    let focusPoint = effectView.captureDevicePointConverted(fromLayerPoint: point)
    HSCameraManager.shared.focus(on: focusPoint)
  }
}
