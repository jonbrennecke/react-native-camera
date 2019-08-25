import MetalKit
import UIKit

class HSEffectPreviewView: UIView {
  private lazy var effectView: HSMetalEffectView = {
    HSMetalEffectView(effectSession: effectSession)
  }()

  internal lazy var effectSession = HSEffectSession()

  public var resizeMode: HSResizeMode {
    get {
      return effectView.resizeMode
    }
    set {
      effectView.resizeMode = newValue
    }
  }

  public var blurAperture: Float {
    get {
      return effectView.blurAperture
    }
    set {
      effectView.blurAperture = newValue
    }
  }

  public var isPaused: Bool {
    get {
      return effectView.isPaused
    }
    set {
      effectView.isPaused = newValue
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
