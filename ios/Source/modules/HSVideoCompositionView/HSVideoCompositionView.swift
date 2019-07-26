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
  
  private var composition: HSVideoComposition? {
    didSet {
      configurePlayer()
    }
  }

  private var asset: AVAsset? {
    didSet {
      if let asset = asset {
        asset.loadValuesAsynchronously(forKeys: ["tracks", "metadata"]) {
          HSVideoComposition.composition(ByLoading: asset) { composition in
            self.composition = composition
          }
        }
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

  private func configurePlayer() {
    guard
      let composition = composition,
      let (avComposition, avVideoComposition) = composition.makeAVComposition()
    else {
        return
    }
    playerItem = AVPlayerItem(asset: avComposition)
    playerItem?.videoComposition = avVideoComposition
    if let compositor = playerItem?.customVideoCompositor as? HSVideoCompositor {
      compositor.depthTrackID = composition.depthTrackID
      compositor.videoTrackID = composition.videoTrackID
      compositor.isDepthPreviewEnabled = isDepthPreviewEnabled
      compositor.isPortraitModeEnabled = isPortraitModeEnabled
    }
    player = AVQueuePlayer(playerItem: playerItem)
    // TODO: configureLooping(timeRange: CMTimeRangeMake(start: CMTime.zero, duration: avComposition.duration))
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
      configurePlayer()
    }
  }

  @objc
  public var isPortraitModeEnabled: Bool = false {
    didSet {
      configurePlayer()
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
