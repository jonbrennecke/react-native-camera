import AVFoundation
import HSCameraUtils
import Photos
import UIKit

@objc
class HSVideoCompositionView: UIView {
  private let loadingQueue = DispatchQueue(label: "com.jonbrennecke.HSVideoCompositionView.loadingQueue")
  private let imageView = UIImageView(frame: .zero)
  private let playerLayer = AVPlayerLayer()
  private var player: AVPlayer?
  private var playerItem: AVPlayerItem?
  private var videoAssetRequestID: PHImageRequestID?
  private var shouldPlayWhenReady: Bool = false

  private var composition: HSVideoComposition? {
    didSet {
      if isReadyToLoad {
        configurePlayer()
      }
    }
  }

  private var asset: AVAsset? {
    didSet {
      if let asset = asset {
        loadComposition(with: asset)
      }
    }
  }

  // MARK: - UIView methods

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    layer.addSublayer(playerLayer)
    addSubview(imageView)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    playerLayer.frame = bounds
    imageView.frame = bounds
  }

  // MARK: - private methods

  private func loadPreviewImage() {
    loadingQueue.async { [weak self] in
      guard
        let strongSelf = self,
        let composition = strongSelf.composition,
        let (avComposition, avVideoComposition) = composition.makeAVComposition()
      else {
        return
      }
      let imageGenerator = AVAssetImageGenerator(asset: avComposition)
      imageGenerator.videoComposition = avVideoComposition
      if let compositor = imageGenerator.customVideoCompositor as? HSVideoCompositor {
        compositor.depthTrackID = composition.depthTrackID
        compositor.videoTrackID = composition.videoTrackID
        compositor.aperture = strongSelf.blurAperture
        compositor.previewMode = strongSelf.previewMode
      }
      let durationSeconds = CMTimeGetSeconds(avComposition.duration)
      let time = CMTimeMakeWithSeconds(durationSeconds * 0.5, preferredTimescale: 600)
      imageGenerator.generateCGImagesAsynchronously(
        forTimes: [NSValue(time: time)]
      ) { [weak self] _, image, _, _, _ in
        guard let image = image else { return }
        DispatchQueue.main.async { [weak self] in
          guard let strongSelf = self else { return }
          let uiImage = UIImage(cgImage: image)
          strongSelf.imageView.contentMode = strongSelf.resizeMode.contentMode
          strongSelf.imageView.image = uiImage
        }
      }
    }
  }

  private func showPreviewImage() {
    if imageView.superview != self {
      imageView.alpha = 0
      addSubview(imageView)
    }
    UIView.animate(withDuration: 0.15) { [weak self] in
      self?.imageView.alpha = 1
    }
  }

  private func hidePreviewImage() {
    let options = UIView.AnimationOptions.curveEaseInOut
    UIView.animate(
      withDuration: 0.15,
      delay: 0.15,
      options: options,
      animations: { [weak self] in
        self?.imageView.alpha = 0
      }, completion: nil
    )
  }

  private func loadComposition(with asset: AVAsset) {
    HSVideoComposition.composition(ByLoading: asset) { [weak self] composition in
      self?.composition = composition
      self?.loadPreviewImage()
    }
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
      compositor.aperture = blurAperture
      compositor.previewMode = previewMode
    }
    player = AVPlayer(playerItem: playerItem)
    player?.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.old, .new], context: nil)
    DispatchQueue.main.async { [weak self] in
      guard let strongSelf = self else { return }
      strongSelf.playerLayer.player = strongSelf.player
      strongSelf.player?.play()
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
    if shouldPlayWhenReady {
      player?.play()
    } else {
      player?.pause()
    }
  }

  // MARK: - objc interface

  @objc
  public var isReadyToLoad: Bool = false {
    didSet {
      if isReadyToLoad {
        configurePlayer()
      }
    }
  }

  @objc
  public var blurAperture: Float = 1.4 {
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
        compositor.aperture = blurAperture
        compositor.previewMode = previewMode
      }
      loadPreviewImage()
    }
  }

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
        compositor.aperture = blurAperture
        compositor.previewMode = previewMode
      }
      loadPreviewImage()
    }
  }

  @objc
  public var resizeMode: HSResizeMode = .scaleAspectFill {
    didSet {
      switch resizeMode {
      case .scaleAspectFill, .scaleAspectHeight:
        playerLayer.videoGravity = .resizeAspectFill
        imageView.contentMode = .scaleAspectFill
      case .scaleAspectWidth:
        playerLayer.videoGravity = .resizeAspect
        imageView.contentMode = .scaleAspectFit
      }
    }
  }

  @objc(loadAssetByID:)
  public func loadAsset(byID assetID: String) {
    loadingQueue.async { [weak self] in
      guard let strongSelf = self else { return }
      if let requestID = strongSelf.videoAssetRequestID {
        PHImageManager.default().cancelImageRequest(requestID)
      }
      strongSelf.videoAssetRequestID = loadVideoAsset(assetID: assetID) { [weak self] asset in
        self?.asset = asset
      }
    }
  }

  @objc
  public func play() {
    hidePreviewImage()
    shouldPlayWhenReady = true
    isReadyToLoad = true
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

fileprivate func loadVideoAsset(assetID: String, _ callback: @escaping (AVAsset?) -> Void) -> PHImageRequestID? {
  let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
  guard let asset = fetchResult.firstObject else {
    callback(nil)
    return nil
  }
  let videoRequestOptions = PHVideoRequestOptions()
  videoRequestOptions.deliveryMode = .highQualityFormat
  return PHImageManager.default()
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
