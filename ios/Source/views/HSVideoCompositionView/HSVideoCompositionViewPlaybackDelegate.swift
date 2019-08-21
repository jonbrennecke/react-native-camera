import Foundation

@objc
public protocol HSVideoCompositionViewPlaybackDelegate: AnyObject {
  func videoComposition(didUpdateProgress progress: CFTimeInterval)
}
