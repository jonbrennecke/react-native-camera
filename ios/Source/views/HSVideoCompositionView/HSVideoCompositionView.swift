import AVFoundation
import HSCameraUtils
import Photos
import UIKit

@objc
class HSVideoCompositionView: UIView {
  private let loadingQueue = DispatchQueue(label: "com.jonbrennecke.HSVideoCompositionView.loadingQueue")
  private var player: AVPlayer?
  private var playerItem: AVPlayerItem?

  private var composition: HSVideoComposition? {
    didSet {
      configurePlayer()
    }
  }

  private var asset: AVAsset? {
    didSet {
      if let asset = asset {
        HSVideoComposition.composition(ByLoading: asset) { composition in
          self.composition = composition
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
      // TODO: throw an error
      return
    }
    playerItem = AVPlayerItem(asset: avComposition)
    playerItem?.videoComposition = avVideoComposition
    if let compositor = playerItem?.customVideoCompositor as? HSVideoCompositor {
      compositor.depthTrackID = composition.depthTrackID
      compositor.videoTrackID = composition.videoTrackID
      compositor.aperture = composition.aperture
      compositor.previewMode = previewMode
    }
    player = AVPlayer(playerItem: playerItem)
    player?.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.old, .new], context: nil)
    DispatchQueue.main.async {
      self.playerLayer.player = self.player
      self.player?.play()
    }
  }

  override func observeValue(
    forKeyPath keyPath: String?, of _: Any?, change: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?
  ) {
    if
      keyPath == #keyPath(AVPlayer.status),
      let statusRawValue = change?[.newKey] as? NSNumber,
      let status = AVPlayer.Status(rawValue: statusRawValue.intValue) {
      if case .readyToPlay = status {
        onReadyToPlay()
      }
    }
  }

  private func onReadyToPlay() {
    player?.seek(to: .zero)
    player?.pause()
  }

  // MARK: - objc interface

  @objc
  public var previewMode: HSEffectPreviewMode = .portraitMode {
    didSet {
      guard
        let composition = composition,
        let (_, avVideoComposition) = composition.makeAVComposition()
      else {
        return
      }
      playerItem?.videoComposition = avVideoComposition
      if let compositor = playerItem?.customVideoCompositor as? HSVideoCompositor {
        compositor.depthTrackID = composition.depthTrackID
        compositor.videoTrackID = composition.videoTrackID
        compositor.aperture = composition.aperture
        compositor.previewMode = previewMode
      }
    }
  }

  @objc(loadAssetByID:)
  public func loadAsset(byID assetID: String) {
    loadingQueue.async {
      loadVideoAsset(assetID: assetID) { asset in
        self.asset = asset
      }
    }
  }

  @objc
  public func play() {
    player?.play()
  }

  @objc
  public func pause() {
    player?.pause()
  }

  @objc
  public func seek(to time: CMTime) {
    player?.seek(to: time)
  }

  @objc(seekToProgress:)
  public func seek(to progress: Double) {
    if let duration = player?.currentItem?.duration {
      let durationSeconds = CMTimeGetSeconds(duration)
      let time = CMTimeMakeWithSeconds(durationSeconds * progress, preferredTimescale: 600)
      seek(to: time)
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
