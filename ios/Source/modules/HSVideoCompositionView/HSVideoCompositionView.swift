import AVFoundation
import HSCameraUtils
import Photos
import UIKit

@objc
class HSVideoCompositionView: UIView {
  private let loadingQueue = DispatchQueue(label: "com.jonbrennecke.HSVideoCompositionView.loadingQueue")
  private var player: AVQueuePlayer?
  private var playerItem: AVPlayerItem?
  private var playerLooper: AVPlayerLooper?

  private var asset: AVAsset? {
    didSet {
      if let asset = asset {
        configure(asset: asset)
      }
    }
  }

  override class var layerClass: AnyClass {
    return AVPlayerLayer.self
  }

  private var playerLayer: AVPlayerLayer {
    return layer as! AVPlayerLayer
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    playerLayer.videoGravity = .resizeAspectFill
  }

  private func configure(asset: AVAsset) {
    asset.loadValuesAsynchronously(forKeys: ["tracks", "playable"]) {
      guard
        let depthTrack = asset.tracks.first(where: { isGrayscaleVideoTrack($0) }),
        let videoTrack = asset.tracks.first(where: { isColorVideoTrack($0) })
      else {
        return
      }
      let renderSize = dimensions(with: videoTrack.formatDescriptions.first as! CMFormatDescription)
      self.configure(
        asset: asset,
        videoTrackID: videoTrack.trackID,
        depthTrackID: depthTrack.trackID,
        renderSize: renderSize
      )
    }
  }

  private func configure(
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
    videoComposition.renderSize = CGSize(width: renderSize.width, height: renderSize.height)
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
    instruction.backgroundColor = UIColor.black.cgColor
    instruction.enablePostProcessing = true
    let timeRange = CMTimeRangeMake(start: CMTime.zero, duration: composition.duration)
    instruction.timeRange = timeRange
    videoComposition.instructions = [instruction]
    videoComposition.customVideoCompositorClass = HSVideoCompositor.self
    playerItem = AVPlayerItem(asset: asset)
    playerItem?.videoComposition = videoComposition
    if let compositor = playerItem?.customVideoCompositor as? HSVideoCompositor {
      compositor.depthTrackID = depthTrackID
      compositor.videoTrackID = videoTrackID
      compositor.isDepthPreviewEnabled = isDepthPreviewEnabled
      compositor.isPortraitModeEnabled = isPortraitModeEnabled
    }
    player = AVQueuePlayer(playerItem: playerItem)
    configureLooping(timeRange: timeRange)
    DispatchQueue.main.async {
      self.playerLayer.player = self.player
      self.player?.play()
    }
  }

  private func configureLooping(timeRange: CMTimeRange) {
    guard shouldLoopVideo, let player = player, let templateItem = playerItem else {
      return
    }
    playerLooper = AVPlayerLooper(
      player: player, templateItem: templateItem, timeRange: timeRange
    )
    if playerLooper?.status == .some(.unknown) {
      print("Looper status is unknown")
    }
  }

  // MARK: - objc interface

  @objc
  public var isDepthPreviewEnabled: Bool = false {
    didSet {
      if let asset = asset {
        configure(asset: asset)
      }
    }
  }

  @objc
  public var isPortraitModeEnabled: Bool = false {
    didSet {
      if let asset = asset {
        configure(asset: asset)
      }
    }
  }

  @objc
  public var shouldLoopVideo: Bool = true

  @objc(loadAssetByID:)
  public func loadAsset(byID assetID: String) {
    loadingQueue.async {
      loadVideoAsset(assetID: assetID) { asset in
        self.asset = asset
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
  let dim = CMVideoFormatDescriptionGetDimensions(formatDescription)
  return Size(width: Int(dim.width), height: Int(dim.height))
}
