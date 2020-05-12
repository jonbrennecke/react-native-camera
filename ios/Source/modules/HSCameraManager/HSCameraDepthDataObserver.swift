import AVFoundation
import ImageUtils

class HSCameraDepthDataObserver: HSObserver {
  private weak var delegate: HSCameraManagerDepthDataDelegate?

  internal init(delegate: HSCameraManagerDepthDataDelegate) {
    self.delegate = delegate
  }

  func cameraManagerDidOutput(disparityPixelBuffer: PixelBuffer, calibrationData: AVCameraCalibrationData?) {
    delegate?.cameraManagerDidOutput(
      disparityPixelBuffer: disparityPixelBuffer,
      calibrationData: calibrationData
    )
  }

  func cameraManagerDidOutput(videoPixelBuffer: PixelBuffer) {
    delegate?.cameraManagerDidOutput(
      videoPixelBuffer: videoPixelBuffer
    )
  }

  func cameraManagerDidFocus(on focusPoint: CGPoint) {
    delegate?.cameraManagerDidFocus(on: focusPoint)
  }
}
