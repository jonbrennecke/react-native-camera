import UIKit

@objc
class HSVideoCompositionBridgeView: HSVideoCompositionView {
  @objc
  public var onPlaybackProgress: RCTDirectEventBlock?

  @objc
  public var onPlaybackStateChange: RCTDirectEventBlock?
}
