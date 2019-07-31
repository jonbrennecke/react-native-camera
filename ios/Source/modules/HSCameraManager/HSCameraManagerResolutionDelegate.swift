import Foundation
import HSCameraUtils

protocol HSCameraManagerResolutionDelegate {
  func cameraManagerDidUpdate(videoResolution: Size<Int>, depthResolution: Size<Int>)
}
