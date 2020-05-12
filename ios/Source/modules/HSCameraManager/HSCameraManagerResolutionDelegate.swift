import Foundation
import ImageUtils

protocol HSCameraManagerResolutionDelegate: AnyObject {
  func cameraManagerDidChange(videoResolution: Size<Int>)
  func cameraManagerDidChange(depthResolution: Size<Int>)
}
