import Foundation

@objc
internal protocol HSVideoCompositionViewPlaybackDelegate: AnyObject {
  @objc(videoCompositionView:didUpdateProgress:)
  func videoComposition(view: HSVideoCompositionView, didUpdateProgress progress: CFTimeInterval)
}
