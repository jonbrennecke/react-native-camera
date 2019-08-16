import AVFoundation
import HSCameraUtils

@available(iOS 11.0, *)
protocol HSCameraManagerDepthDataDelegate: AnyObject {
  func cameraManagerDidOutput(disparityPixelBuffer: HSPixelBuffer)
  func cameraManagerDidOutput(videoPixelBuffer: HSPixelBuffer)
}
