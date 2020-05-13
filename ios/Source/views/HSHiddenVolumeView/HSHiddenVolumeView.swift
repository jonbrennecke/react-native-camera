import MediaPlayer
import UIKit

@objc
class HSHiddenVolumeView: UIView {
  private let volumeView: MPVolumeView = {
    let view = MPVolumeView(frame: .zero)
    view.isHidden = false
    view.alpha = 0.0001
    return view
  }()

  override public func didMoveToSuperview() {
    super.didMoveToSuperview()
    addSubview(volumeView)
  }
}
