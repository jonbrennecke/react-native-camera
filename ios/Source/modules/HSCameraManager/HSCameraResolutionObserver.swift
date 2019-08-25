import Foundation
import HSCameraUtils

class HSCameraResolutionObserver: HSObserver {
  private weak var delegate: HSCameraManagerResolutionDelegate?

  internal init(delegate: HSCameraManagerResolutionDelegate) {
    self.delegate = delegate
  }

  func cameraManagerDidChangeResolution(videoResolution: Size<Int>, depthResolution: Size<Int>) {
    delegate?.cameraManagerDidChangeResolution(videoResolution: videoResolution, depthResolution: depthResolution)
  }
}
