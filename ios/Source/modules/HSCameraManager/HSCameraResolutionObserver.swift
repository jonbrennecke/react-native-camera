import Foundation
import HSCameraUtils

class HSCameraResolutionObserver: HSObserver {
  private weak var delegate: HSCameraManagerResolutionDelegate?

  internal init(delegate: HSCameraManagerResolutionDelegate) {
    self.delegate = delegate
  }

  func cameraManagerDidChange(videoResolution: Size<Int>) {
    delegate?.cameraManagerDidChange(videoResolution: videoResolution)
  }

  func cameraManagerDidChange(depthResolution: Size<Int>) {
    delegate?.cameraManagerDidChange(depthResolution: depthResolution)
  }
}
