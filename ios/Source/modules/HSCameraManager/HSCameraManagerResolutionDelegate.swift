import Foundation
import HSCameraUtils

protocol HSCameraManagerResolutionDelegate: AnyObject {
  func cameraManagerDidChangeResolution(videoResolution: Size<Int>, depthResolution: Size<Int>)
}
