import AVFoundation

class HSVideoCompositionInstruction: AVMutableVideoCompositionInstruction {
  internal let depthTrackID: CMPersistentTrackID
  internal let videoTrackID: CMPersistentTrackID
  internal let isDepthPreviewEnabled: Bool

  init(depthTrackID: CMPersistentTrackID, videoTrackID: CMPersistentTrackID, isDepthPreviewEnabled: Bool) {
    self.depthTrackID = depthTrackID
    self.videoTrackID = videoTrackID
    self.isDepthPreviewEnabled = isDepthPreviewEnabled
    super.init()
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
