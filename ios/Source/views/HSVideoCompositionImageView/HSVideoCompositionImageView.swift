import AVFoundation
import UIKit

@objc
class HSVideoCompositionImageView: UIImageView {
  private let loadingQueue = DispatchQueue(
    label: "com.jonbrennecke.HSVideoCompositionView.loadingQueue",
    qos: .background
  )

  private var assetURL: URL?
  private var assetImageGenerator: AVAssetImageGenerator?

  @objc
  public var resizeMode: HSResizeMode = .scaleAspectWidth {
    didSet {
      reloadImage()
    }
  }

  @objc
  public var blurAperture: Float = 2.4 {
    didSet {
      reloadImage()
    }
  }

  @objc
  public var previewMode: HSEffectPreviewMode = .portraitMode {
    didSet {
      reloadImage()
    }
  }

  @objc
  public var progress: Float = 0 {
    didSet {
      reloadImage()
    }
  }

  @objc(generateImageByResourceName:extension:completionHandler:)
  public func generateImage(
    byResourceName name: String, extension ext: String, _ completionHandler: (() -> Void)?
  ) {
    loadingQueue.async { [weak self] in
      guard let strongSelf = self else { return }
      guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
        completionHandler?()
        return
      }
      strongSelf.assetURL = url
      let asset = AVAsset(url: url)
      strongSelf.generateImage(withAsset: asset) { [weak self] image in
        guard let strongSelf = self else { return }
        if let cgImage = image {
          strongSelf.setImage(cgImage)
        }
        completionHandler?()
      }
    }
  }

  private func generateImage(withAsset asset: AVAsset, _ completionHandler: @escaping (CGImage?) -> Void) {
    loadingQueue.async { [weak self] in
      guard self != nil else { return }
      HSVideoComposition.composition(byLoading: asset) { [weak self] composition in
        guard let strongSelf = self else { return }
        guard let composition = composition else {
          completionHandler(nil)
          return
        }
        strongSelf.generateImage(withComposition: composition) { [weak self] image in
          guard self != nil else { return }
          completionHandler(image)
        }
      }
    }
  }

  private func generateImage(
    withComposition composition: HSVideoComposition,
    _ completionHandler: @escaping (CGImage?) -> Void
  ) {
    loadingQueue.async { [weak self] in
      guard let strongSelf = self else { return }
      guard let (avComposition, avVideoComposition) = composition.makeAVComposition() else {
        completionHandler(nil)
        return
      }
      let imageGenerator = AVAssetImageGenerator(asset: avComposition)
      strongSelf.assetImageGenerator = imageGenerator
      imageGenerator.videoComposition = avVideoComposition
      if let compositor = imageGenerator.customVideoCompositor as? HSVideoCompositor {
        compositor.depthTrackID = composition.depthTrackID
        compositor.videoTrackID = composition.videoTrackID
        compositor.aperture = strongSelf.blurAperture
        compositor.previewMode = strongSelf.previewMode
      }
      let durationSeconds = CMTimeGetSeconds(imageGenerator.asset.duration)
      let time = CMTimeMakeWithSeconds(durationSeconds * Double(strongSelf.progress), preferredTimescale: 600)
      imageGenerator.generateCGImagesAsynchronously(
        forTimes: [NSValue(time: time)]
      ) { [weak self] _, image, _, _, _ in
        guard self != nil else { return }
        completionHandler(image)
      }
    }
  }

  private func reloadImage() {
    regenerateImage { [weak self] image in
      guard let strongSelf = self else { return }
      if let cgImage = image {
        strongSelf.setImage(cgImage)
      }
    }
  }

  private func regenerateImage(_ completionHandler: ((CGImage?) -> Void)?) {
    loadingQueue.async { [weak self] in
      guard let strongSelf = self else { return }
      guard let imageGenerator = strongSelf.assetImageGenerator else {
        completionHandler?(nil)
        return
      }
      imageGenerator.cancelAllCGImageGeneration()
      if let compositor = imageGenerator.customVideoCompositor as? HSVideoCompositor {
        compositor.aperture = strongSelf.blurAperture
        compositor.previewMode = strongSelf.previewMode
      }
      let durationSeconds = CMTimeGetSeconds(imageGenerator.asset.duration)
      let time = CMTimeMakeWithSeconds(durationSeconds * Double(strongSelf.progress), preferredTimescale: 600)
      imageGenerator.generateCGImagesAsynchronously(
        forTimes: [NSValue(time: time)]
      ) { [weak self] _, image, _, _, _ in
        guard self != nil else { return }
        completionHandler?(image)
      }
    }
  }

  private func reloadImageFromURL() {
    if let url = assetURL {
      let asset = AVAsset(url: url)
      generateImage(withAsset: asset) { [weak self] image in
        guard let strongSelf = self else { return }
        if let cgImage = image {
          strongSelf.setImage(cgImage)
        }
      }
    }
  }

  private func setImage(_ cgImage: CGImage) {
    DispatchQueue.main.async { [weak self] in
      guard let strongSelf = self else { return }
      let uiImage = UIImage(cgImage: cgImage)
      strongSelf.contentMode = strongSelf.resizeMode.contentMode
      strongSelf.image = uiImage
    }
  }
}
