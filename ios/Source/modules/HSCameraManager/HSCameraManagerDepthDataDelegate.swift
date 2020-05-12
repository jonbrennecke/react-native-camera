import AVFoundation
import ImageUtils

@available(iOS 11.0, *)
protocol HSCameraManagerDepthDataDelegate: AnyObject {
  var isPaused: Bool { get set }
  func cameraManagerDidOutput(disparityPixelBuffer: PixelBuffer, calibrationData: AVCameraCalibrationData?)
  func cameraManagerDidOutput(videoPixelBuffer: PixelBuffer)
  func cameraManagerDidFocus(on focusPoint: CGPoint)
}
