import Photos

@objc
protocol HSCameraManagerDelegate {
  func cameraManagerDidReceiveCameraDataOutput(videoData: CMSampleBuffer)
  func cameraManagerDidBeginFileOutput(toFileURL fileURL: URL)
  func cameraManagerDidFinishFileOutput(toFileURL fileURL: URL, asset: PHObjectPlaceholder?, error: Error?)
  @objc(cameraManagerDidDetectFaces:)
  func cameraManagerDidDetect(faces: [AVMetadataFaceObject])
}
