import AVFoundation
import Photos

@objc
class HSEffectComposition: NSObject {
  private var player: AVPlayer?

  @objc(sharedInstance)
  public static let shared = HSEffectComposition()

  @objc
  public func compose(assetID: String) {
    loadVideoAsset(assetID: assetID) { asset in
      guard let asset = asset else {
        return
      }
//      asset.loadValuesAsynchronously(forKeys: ["tracks"], completionHandler: <#T##(() -> Void)?##(() -> Void)?##() -> Void#>)
      let playerItem = AVPlayerItem(asset: asset)
      playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.tracks), options: [.old, .new], context: nil)
      self.player = AVPlayer(playerItem: playerItem)
    }
  }

  override func observeValue(
    forKeyPath keyPath: String?, of _: Any?, change: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?
  ) {
    if keyPath == #keyPath(AVPlayerItem.tracks) {
      guard let tracks = change?[.newKey] as? [AVPlayerItemTrack] else {
        return
      }
      let mediaTypes = tracks.map { $0.assetTrack?.mediaType }
      print(mediaTypes)
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
