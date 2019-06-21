import AVFoundation

@available(iOS 11.0, *)
@objc
protocol HSCameraManagerDepthDataDelegate {
    @objc(cameraManagerDidOutputDepthData:videoData:)
    func cameraManagerDidOutput(depthData: AVDepthData, videoData: CMSampleBuffer)
}
