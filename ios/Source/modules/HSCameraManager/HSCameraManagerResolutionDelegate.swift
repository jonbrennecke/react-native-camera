import Foundation
import HSCameraUtils

protocol HSCameraManagerResolutionDelegate: AnyObject {
  func cameraManagerDidChange(videoResolution: Size<Int>)
  func cameraManagerDidChange(depthResolution: Size<Int>)
}
