import AVFoundation
import HSCameraUtils

@available(iOS 11.0, *)
protocol HSCameraManagerDepthDataDelegate: AnyObject {
  var isPaused: Bool { get set }
  func cameraManagerDidOutput(disparityPixelBuffer: HSPixelBuffer, calibrationData: AVCameraCalibrationData?)
  func cameraManagerDidOutput(videoPixelBuffer: HSPixelBuffer)
}
