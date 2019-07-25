import AVFoundation

@objc
class HSVideoComposition: NSObject {
  private let asset: AVAsset

  internal let videoTrackID: CMPersistentTrackID
  internal let depthTrackID: CMPersistentTrackID

  @objc
  public init(asset: AVAsset, videoTrackID: CMPersistentTrackID, depthTrackID: CMPersistentTrackID) {
    self.asset = asset
    self.videoTrackID = videoTrackID
    self.depthTrackID = depthTrackID
  }

  @objc(compositionByLoadingAsset:withCompletionHandler:)
  public static func composition(ByLoading asset: AVAsset, _ completionHandler: @escaping (HSVideoComposition?) -> Void) {
    asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
      guard
        let depthTrack = asset.tracks.first(where: { isGrayscaleVideoTrack($0) }),
        let videoTrack = asset.tracks.first(where: { isColorVideoTrack($0) })
      else {
        completionHandler(nil)
        return
      }
      let composition = HSVideoComposition(
        asset: asset,
        videoTrackID: videoTrack.trackID,
        depthTrackID: depthTrack.trackID
      )
      completionHandler(composition)
    }
  }

  internal func makeAVComposition() -> (AVComposition, AVVideoComposition)? {
    guard
      let videoTrack = asset.track(withTrackID: videoTrackID),
      let depthTrack = asset.track(withTrackID: depthTrackID)
    else {
      return nil
    }
    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = videoTrack.naturalSize
    videoComposition.frameDuration = CMTimeMake(value: 1, timescale: CMTimeScale(videoTrack.nominalFrameRate))

    let composition = AVMutableComposition()
    let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: videoTrackID)
    try? compositionVideoTrack?.insertTimeRange(videoTrack.timeRange, of: videoTrack, at: .zero)
    let videoLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
    videoLayerInstruction.setTransform(videoTrack.preferredTransform, at: .zero)

    let compositionDepthTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: depthTrackID)
    try? compositionDepthTrack?.insertTimeRange(depthTrack.timeRange, of: depthTrack, at: .zero)
    let depthLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: depthTrack)
    depthLayerInstruction.setTransform(depthTrack.preferredTransform, at: .zero)

    let instruction = AVMutableVideoCompositionInstruction()
    instruction.layerInstructions = [
      videoLayerInstruction,
      depthLayerInstruction,
    ]
    instruction.enablePostProcessing = true
    let timeRange = CMTimeRangeMake(start: CMTime.zero, duration: composition.duration)
    instruction.timeRange = timeRange
    videoComposition.instructions = [instruction]
    videoComposition.customVideoCompositorClass = HSVideoCompositor.self
    return (composition, videoComposition)
  }
}

// TODO: needs improvement; this is a super hacky way to check whether or not a track is color
fileprivate func isGrayscaleVideoTrack(_ track: AVAssetTrack) -> Bool {
  guard
    track.mediaType == .video,
    let formatDescription = track.formatDescriptions.first,
    let ext = CMFormatDescriptionGetExtensions(formatDescription as! CMFormatDescription) as? [String: AnyObject],
    case .none = ext[kCVImageBufferYCbCrMatrixKey as String]
  else {
    return false
  }
  return true
}

fileprivate func isColorVideoTrack(_ track: AVAssetTrack) -> Bool {
  guard
    track.mediaType == .video,
    let formatDescription = track.formatDescriptions.first,
    let ext = CMFormatDescriptionGetExtensions(formatDescription as! CMFormatDescription) as? [String: AnyObject],
    case .some = ext[kCVImageBufferYCbCrMatrixKey as String]
  else {
    return false
  }
  return true
}
