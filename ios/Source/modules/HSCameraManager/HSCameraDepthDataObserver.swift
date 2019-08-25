import Foundation
import HSCameraUtils

class HSCameraDepthDataObserver: HSObserver {
  private weak var delegate: HSCameraManagerDepthDataDelegate?

  internal init(delegate: HSCameraManagerDepthDataDelegate) {
    self.delegate = delegate
  }

  func cameraManagerDidOutput(disparityPixelBuffer: HSPixelBuffer) {
    delegate?.cameraManagerDidOutput(disparityPixelBuffer: disparityPixelBuffer)
  }

  func cameraManagerDidOutput(videoPixelBuffer: HSPixelBuffer) {
    delegate?.cameraManagerDidOutput(videoPixelBuffer: videoPixelBuffer)
  }
}
