import AVFoundation
import Photos

@objc
class HSEffectComposition: NSObject {
  @objc(compositionWithAssetID:)
  public static func composition(with assetID: String) {
    loadVideoAsset(assetID: assetID) { asset in
      guard let asset = asset else {
        return
      }
      let playerItem = AVPlayerItem(asset: asset)
      print(playerItem.tracks)
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
