import AVFoundation

@objc
class HSVideoComposition: NSObject {
  private let asset: AVAsset
  internal let videoTrackID: CMPersistentTrackID
  internal let depthTrackID: CMPersistentTrackID
  internal var metadata: [String: Any]

  @objc(setMetadataValue:forKey:)
  public func setMetadata(value: Any, key: String) {
    metadata[key] = value
  }

  public init(
    asset: AVAsset,
    videoTrackID: CMPersistentTrackID,
    depthTrackID: CMPersistentTrackID,
    metadata: [String: Any]
  ) {
    self.asset = asset
    self.videoTrackID = videoTrackID
    self.depthTrackID = depthTrackID
    self.metadata = metadata
  }

  @objc(compositionByLoadingAsset:withCompletionHandler:)
  public static func composition(byLoading asset: AVAsset, _ completionHandler: @escaping (HSVideoComposition?) -> Void) {
    asset.loadValuesAsynchronously(forKeys: ["tracks", "metadata"]) {
      guard
        let depthTrack = asset.tracks.first(where: { isGrayscaleVideoTrack($0) }),
        let videoTrack = asset.tracks.first(where: { isColorVideoTrack($0) })
      else {
        completionHandler(nil)
        return
      }
      let metadata = parseMetadata(asset.metadata)
      let composition = HSVideoComposition(
        asset: asset,
        videoTrackID: videoTrack.trackID,
        depthTrackID: depthTrack.trackID,
        metadata: metadata ?? [:]
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

    // add optional audio track
    if
      let audioTrack = asset.tracks.first(where: { $0.mediaType == .audio }),
      let compositionAudioTrack = composition.addMutableTrack(
        withMediaType: .audio, preferredTrackID: audioTrack.trackID
      ) {
      try? compositionAudioTrack.insertTimeRange(audioTrack.timeRange, of: audioTrack, at: .zero)
    }

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

  // MARK: - private utility functions

  private static func parseMetadata(_ metadata: [AVMetadataItem]) -> [String: Any]? {
    let keySpace = AVMetadataKeySpace.quickTimeUserData
    let key = AVMetadataKey.quickTimeUserDataKeyInformation
    let items = AVMetadataItem.metadataItems(from: metadata, withKey: key, keySpace: keySpace)
    if
      let jsonString = items.first?.value as? String,
      let jsonData = jsonString.data(using: .ascii),
      let jsonDict = try? JSONSerialization.jsonObject(
        with: jsonData, options: JSONSerialization.ReadingOptions()
      ) as? [String: Any] {
      return jsonDict
    }
    return nil
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
