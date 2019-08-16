import Foundation

protocol HSCameraManagerPlaybackDelegate: AnyObject {
  func cameraManagerDidBeginCapture()
  func cameraManagerDidEndCapture()
  func cameraManagerDidBeginPreview()
  func cameraManagerDidEndPreview()
}
