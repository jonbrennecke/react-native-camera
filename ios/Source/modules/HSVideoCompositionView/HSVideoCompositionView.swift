import AVFoundation
import HSCameraUtils
import Photos
import UIKit

@objc
class HSVideoCompositionView: UIView {
  private var player: AVQueuePlayer?
  private var playerItem: AVPlayerItem?
  private var playerLooper: AVPlayerLooper?

  override class var layerClass: AnyClass {
    return AVPlayerLayer.self
  }

  private var playerLayer: AVPlayerLayer {
    return layer as! AVPlayerLayer
  }

  private func load(asset: AVAsset) {
    asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
      guard
        let depthTrack = asset.tracks.first(where: { isGrayscaleVideoTrack($0) }),
        let videoTrack = asset.tracks.first(where: { isColorVideoTrack($0) })
      else {
        return
      }
      let videoTrackID = videoTrack.trackID
      let depthTrackID = depthTrack.trackID
      let renderSize = dimensions(with: videoTrack.formatDescriptions.first as! CMFormatDescription)
      self.configurePlayer(
        asset: asset,
        videoTrackID: videoTrackID,
        depthTrackID: depthTrackID,
        renderSize: renderSize
      )
    }
  }

  private func configurePlayer(
    asset: AVAsset,
    videoTrackID: CMPersistentTrackID,
    depthTrackID: CMPersistentTrackID,
    renderSize: Size<Int>
  ) {
    guard
      let videoTrack = asset.track(withTrackID: videoTrackID),
      let depthTrack = asset.track(withTrackID: depthTrackID)
    else {
      return
    }

    let videoComposition = AVMutableVideoComposition()
    videoComposition.customVideoCompositorClass = HSVideoCompositor.self
    videoComposition.renderSize = CGSize(width: renderSize.width, height: renderSize.height)
    videoComposition.frameDuration = CMTimeMake(value: 1, timescale: CMTimeScale(videoTrack.nominalFrameRate))
    let composition = AVMutableComposition()
    let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    try? compositionVideoTrack?.insertTimeRange(videoTrack.timeRange, of: videoTrack, at: CMTime.zero)
    let compositionDepthTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    try? compositionDepthTrack?.insertTimeRange(depthTrack.timeRange, of: depthTrack, at: CMTime.zero)
    let videoLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
    videoLayerInstruction.setTransform(videoTrack.preferredTransform, at: CMTime.zero)
    let depthLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: depthTrack)
    depthLayerInstruction.setTransform(depthTrack.preferredTransform, at: CMTime.zero)
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.layerInstructions = [
      videoLayerInstruction,
      depthLayerInstruction,
    ]
    instruction.backgroundColor = UIColor.black.cgColor
    instruction.enablePostProcessing = true
    instruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: composition.duration)
    videoComposition.instructions = [instruction]
    playerItem = AVPlayerItem(asset: asset)
    playerItem?.videoComposition = videoComposition
    if let compositor = playerItem?.customVideoCompositor as? HSVideoCompositor {
      compositor.depthTrackID = depthTrackID
      compositor.videoTrackID = videoTrackID
      compositor.isDepthPreviewEnabled = isDepthPreviewEnabled
    }
    player = AVQueuePlayer(playerItem: playerItem)
    playerLooper = AVPlayerLooper(player: player!, templateItem: playerItem!)
    DispatchQueue.main.async {
      self.playerLayer.player = self.player
      self.player?.play()
    }
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    playerLayer.videoGravity = .resizeAspectFill
  }
  
  @objc
  public var isDepthPreviewEnabled: Bool = false
  
  @objc
  public var assetID: String? {
    didSet {
      guard let id = assetID else {
        return
      }
      loadVideoAsset(assetID: id) { asset in
        guard let asset = asset else {
          return
        }
        self.load(asset: asset)
      }
    }
  }
}

fileprivate func loadVideoAsset(assetID: String, _ callback: @escaping (AVAsset?) -> Void) {
  let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
  guard let asset = fetchResult.firstObject else {
    return callback(nil)
  }
  let videoRequestOptions = PHVideoRequestOptions()
  videoRequestOptions.deliveryMode = .highQualityFormat
  PHImageManager.default()
    .requestAVAsset(forVideo: asset, options: videoRequestOptions) { asset, _, _ in
      callback(asset)
    }
}

// TODO: this is a super hacky way to check if a track is color or not
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

fileprivate func dimensions(of track: AVAssetTrack) -> Size<Int>? {
  guard
    track.mediaType == .video,
    let formatDescription = track.formatDescriptions.first
  else {
    return nil
  }
  return dimensions(with: formatDescription as! CMFormatDescription)
}

fileprivate func dimensions(with formatDescription: CMFormatDescription) -> Size<Int> {
  let dim = CMVideoFormatDescriptionGetDimensions(formatDescription as! CMFormatDescription)
  return Size(width: Int(dim.width), height: Int(dim.height))
}
