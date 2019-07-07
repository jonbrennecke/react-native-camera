import AVFoundation

@available(iOS 11.0, *)
@objc
protocol HSCameraManagerDepthDataDelegate {
  @objc(cameraManagerDidOutputDepthData:)
  func cameraManagerDidOutput(depthData: AVDepthData)
  @objc(cameraManagerDidOutputVideoSampleBuffer:)
  func cameraManagerDidOutput(videoSampleBuffer: CMSampleBuffer)
}
