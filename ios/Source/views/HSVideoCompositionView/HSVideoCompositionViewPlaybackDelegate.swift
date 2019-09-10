import Foundation

@objc
internal protocol HSVideoCompositionViewPlaybackDelegate: AnyObject {
  @objc(videoCompositionView:didUpdateProgress:)
  func videoComposition(view: HSVideoCompositionView, didUpdateProgress progress: CFTimeInterval)

  @objc(videoCompositionView:didChangePlaybackState:)
  func videoComposition(view: HSVideoCompositionView, didChangePlaybackState playbackState: HSVideoPlaybackState)

  @objc(videoCompositionView:didLoadMetadata:)
  func videoComposition(view: HSVideoCompositionView, didLoadMetadata metadata: [String: Any])

  @objc(videoCompositionViewDidPlayToEnd:)
  func videoCompositionDidPlayToEnd(_ view: HSVideoCompositionView)
}
