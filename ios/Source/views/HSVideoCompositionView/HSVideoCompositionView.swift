import AVFoundation
import HSCameraUtils
import Photos
import UIKit

@objc
class HSVideoCompositionView: UIView {
  private let loadingQueue = DispatchQueue(
    label: "com.jonbrennecke.HSVideoCompositionView.loadingQueue",
    qos: .background
  )
  private let imageView = UIImageView(frame: .zero)
  private let playerLayer = AVPlayerLayer()
  private var player: AVPlayer = {
    let player = AVPlayer()
    player.volume = 1
    return player
  }()

  private var playerItem: AVPlayerItem?
  private var videoAssetRequestID: PHImageRequestID?
  private var shouldPlayWhenReady: Bool = false
  private var playbackTimeObserverToken: Any?
  private var blurAperture: Float = 2.4

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

  @objc
  public weak var playbackDelegate: HSVideoCompositionViewPlaybackDelegate?

  deinit {
    NotificationCenter.default.removeObserver(self)
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
        compositor.blurAperture = strongSelf.blurAperture
        compositor.previewMode = strongSelf.previewMode
      }
      let time = CMTimeMakeWithSeconds(.zero, preferredTimescale: 600)
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
    HSVideoComposition.composition(byLoading: asset) { [weak self] composition in
      guard let strongSelf = self else { return }
      strongSelf.composition = composition
      if let metadata = composition?.metadata {
        strongSelf.playbackDelegate?.videoComposition(view: strongSelf, didLoadMetadata: metadata)
      }
      strongSelf.loadPreviewImage()
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
    let audioSession = AVAudioSession.sharedInstance()
    try? audioSession.setCategory(.playback)
    try? audioSession.setActive(true, options: .init())
    playerItem = AVPlayerItem(asset: avComposition)
    playerItem?.videoComposition = avVideoComposition
    if let compositor = playerItem?.customVideoCompositor as? HSVideoCompositor {
      compositor.depthTrackID = composition.depthTrackID
      compositor.videoTrackID = composition.videoTrackID
      compositor.blurAperture = blurAperture
      compositor.previewMode = previewMode
    }
    player.replaceCurrentItem(with: playerItem)
    player.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.old, .new], context: nil)
    player.addObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus), options: [.old, .new], context: nil)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onDidPlayToEndNotification),
      name: Notification.Name.AVPlayerItemDidPlayToEndTime,
      object: nil
    )
    playerLayer.player = player
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

    if
      keyPath == #keyPath(AVPlayer.timeControlStatus),
      let newStatusRawValue = change?[.newKey] as? NSNumber,
      let oldStatusRawValue = change?[.oldKey] as? NSNumber,
      oldStatusRawValue != newStatusRawValue,
      let status = AVPlayer.TimeControlStatus(rawValue: newStatusRawValue.intValue) {
      switch status {
      case .waitingToPlayAtSpecifiedRate:
        playbackDelegate?.videoComposition(view: self, didChangePlaybackState: .waiting)
      case .paused:
        playbackDelegate?.videoComposition(view: self, didChangePlaybackState: .paused)
      case .playing:
        playbackDelegate?.videoComposition(view: self, didChangePlaybackState: .playing)
        @unknown default:
        break
      }
    }
  }

  private func addPeriodicTimeObserver() {
    let timeScale = CMTimeScale(NSEC_PER_SEC)
    let timeInterval = CMTime(seconds: 1 / 30, preferredTimescale: timeScale)
    playbackTimeObserverToken = player.addPeriodicTimeObserver(
      forInterval: timeInterval,
      queue: .main,
      using: { [weak self] playbackTime in
        guard let strongSelf = self, let duration = strongSelf.playerItem?.duration else { return }
        let playbackTimeSeconds = CMTimeGetSeconds(playbackTime)
        let durationSeconds = CMTimeGetSeconds(duration)
        let progress = clamp(playbackTimeSeconds / durationSeconds, min: 0, max: durationSeconds)
        strongSelf.playbackDelegate?.videoComposition(view: strongSelf, didUpdateProgress: progress)
      }
    )
  }

  private func removePeriodicTimeObserver() {
    if let token = playbackTimeObserverToken {
      player.removeTimeObserver(token)
      playbackTimeObserverToken = nil
    }
  }

  private func onReadyToPlay() {
    removePeriodicTimeObserver()
    addPeriodicTimeObserver()
    playbackDelegate?.videoComposition(view: self, didChangePlaybackState: .readyToPlay)
    if shouldPlayWhenReady {
      player.play()
    } else {
      player.pause()
    }
  }

  @objc
  private func onDidPlayToEndNotification() {
    playbackDelegate?.videoCompositionDidPlayToEnd(self)
  }

  // MARK: - objc interface

  @objc
  public var isReadyToLoad: Bool = false {
    didSet {
      if isReadyToLoad, !oldValue {
        configurePlayer()
      }
    }
  }

  @objc
  public func setBlurAperture(_ blurAperture: Float) {
    self.blurAperture = blurAperture
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
      compositor.blurAperture = blurAperture
      compositor.previewMode = previewMode
    }
    loadPreviewImage()
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
        compositor.blurAperture = blurAperture
        compositor.previewMode = previewMode
      }
      loadPreviewImage()
    }
  }

  @objc
  public func setWatermarkImageNameWithExtension(_ fileName: String?) {
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
      compositor.blurAperture = blurAperture
      compositor.previewMode = previewMode
      compositor.watermarkProperties = fileName != nil ? HSDepthBlurEffect.WatermarkProperties(
        fileName: fileName!, fileExtension: ""
      ) : nil
    }
    loadPreviewImage()
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
    player.play()
  }

  @objc
  public func pause() {
    player.pause()
  }

  @objc
  public func seek(to time: CMTime) {
    player.seek(to: time)
  }

  @objc(seekToProgress:)
  public func seek(to progress: Double) {
    if let duration = player.currentItem?.duration {
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
