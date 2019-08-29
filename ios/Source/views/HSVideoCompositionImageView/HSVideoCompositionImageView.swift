import AVFoundation
import UIKit

@objc
class HSVideoCompositionImageView: UIImageView {
  private let loadingQueue = DispatchQueue(
    label: "com.jonbrennecke.HSVideoCompositionView.loadingQueue",
    qos: .background
  )

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
    let size = frame.size
    loadingQueue.async { [weak self] in
      guard let strongSelf = self else { return }
      guard let path = Bundle.main.path(forResource: name, ofType: ext) else {
        completionHandler?()
        return
      }
      let url = URL(fileURLWithPath: path)
      let asset = AVAsset(url: url)
      strongSelf.generateImage(withAsset: asset, size: size) { [weak self] image in
        guard let strongSelf = self else { return }
        if let cgImage = image {
          strongSelf.setImage(cgImage)
        }
        completionHandler?()
      }
    }
  }

  private func generateImage(withAsset asset: AVAsset, size: CGSize, _ completionHandler: @escaping (CGImage?) -> Void) {
    loadingQueue.async { [weak self] in
      guard self != nil else { return }
      HSVideoComposition.composition(byLoading: asset) { [weak self] composition in
        guard let strongSelf = self else { return }
        guard let composition = composition else {
          completionHandler(nil)
          return
        }
        strongSelf.generateImage(withComposition: composition, size: size) { [weak self] image in
          guard self != nil else { return }
          completionHandler(image)
        }
      }
    }
  }

  private func generateImage(
    withComposition composition: HSVideoComposition,
    size: CGSize,
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
      imageGenerator.requestedTimeToleranceAfter = .zero
      imageGenerator.requestedTimeToleranceBefore = .zero
      imageGenerator.appliesPreferredTrackTransform = true
      imageGenerator.maximumSize = size
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
    regenerateImage(size: frame.size) { [weak self] image in
      guard let strongSelf = self else { return }
      if let cgImage = image {
        strongSelf.setImage(cgImage)
      }
    }
  }

  private func regenerateImage(size: CGSize, _ completionHandler: ((CGImage?) -> Void)?) {
    loadingQueue.async { [weak self] in
      guard let strongSelf = self else { return }
      guard let imageGenerator = strongSelf.assetImageGenerator else {
        completionHandler?(nil)
        return
      }
      imageGenerator.cancelAllCGImageGeneration()
      imageGenerator.requestedTimeToleranceAfter = .zero
      imageGenerator.requestedTimeToleranceBefore = .zero
      imageGenerator.appliesPreferredTrackTransform = true
      imageGenerator.maximumSize = size
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

  private func setImage(_ cgImage: CGImage) {
    DispatchQueue.main.async { [weak self] in
      guard let strongSelf = self else { return }
      let uiImage = UIImage(cgImage: cgImage)
      strongSelf.contentMode = strongSelf.resizeMode.contentMode
      strongSelf.image = uiImage
    }
  }
}
