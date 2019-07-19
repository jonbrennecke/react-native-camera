import AVFoundation
import Photos
import UIKit

@objc
class HSVideoCompositionView: UIView {
  private var player: AVPlayer?
  private var item: AVPlayerItem?
  private var playerLooper: AVPlayerLooper?

  override class var layerClass: AnyClass {
    return AVPlayerLayer.self
  }

  private var playerLayer: AVPlayerLayer {
    return layer as! AVPlayerLayer
  }

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

  private func load(asset: AVAsset) {
    asset.loadValuesAsynchronously(forKeys: ["tracks"], completionHandler: {
//      let mediaTypes = asset.tracks.map { $0.mediaType }
      // if multiple video tracks
      // if video pixelFormatType === kCVPixelFormatType_OneComponent8
    })

    let playerItem = AVPlayerItem(asset: asset)
    playerItem.videoComposition = AVVideoComposition(asset: asset) { request in
      let blurred = request.sourceImage.clampedToExtent().applyingGaussianBlur(sigma: 10)
      let output = blurred.clamped(to: request.sourceImage.extent)
      request.finish(with: output, context: nil)
    }
    player = AVPlayer(playerItem: playerItem)
    DispatchQueue.main.async {
      self.playerLayer.player = self.player
    }
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    playerLayer.videoGravity = .resizeAspectFill
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
