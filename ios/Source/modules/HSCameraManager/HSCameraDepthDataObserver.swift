import AVFoundation
import HSCameraUtils

class HSCameraDepthDataObserver: HSObserver {
  private weak var delegate: HSCameraManagerDepthDataDelegate?

  internal init(delegate: HSCameraManagerDepthDataDelegate) {
    self.delegate = delegate
  }

  func cameraManagerDidOutput(disparityPixelBuffer: HSPixelBuffer, calibrationData: AVCameraCalibrationData?) {
    delegate?.cameraManagerDidOutput(
      disparityPixelBuffer: disparityPixelBuffer,
      calibrationData: calibrationData
    )
  }

  func cameraManagerDidOutput(videoPixelBuffer: HSPixelBuffer) {
    delegate?.cameraManagerDidOutput(
      videoPixelBuffer: videoPixelBuffer
    )
  }

  func cameraManagerDidFocus(on focusPoint: CGPoint) {
    delegate?.cameraManagerDidFocus(on: focusPoint)
  }
}
