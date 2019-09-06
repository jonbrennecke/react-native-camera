import Foundation
import Photos

@objc
enum HSVideoCompositionExportError: Int, Error {
  case failedToExport
}

@objc
class HSVideoCompositionExportManager: NSObject {
  private let exportManager = HSExportManager()

  @objc(sharedInstance)
  public static let shared = HSVideoCompositionExportManager()

  @objc
  public var delegate: HSVideoCompositionExportManagerDelegate?

  @objc(exportComposition:)
  public func export(composition: HSVideoComposition) {
    let task = HSVideoCompositionExportTask(composition: composition)
    exportManager.delegate = self
    exportManager.export(task: task)
  }
}

extension HSVideoCompositionExportManager: HSExportManagerDelegate {
  func videoExportManager(didFinishTask task: HSExportTask) {
    if let task = task as? HSVideoCompositionExportTask, let url = task.outputURL {
      var localIdentifier: String?
      PHPhotoLibrary.shared().performChanges({
        let request = PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
        localIdentifier = request?.placeholderForCreatedAsset?.localIdentifier
      }) { [weak self] _, _ in
        guard let strongSelf = self else { return }
        guard let locationID = localIdentifier else {
          strongSelf.delegate?.videoExportManager(didFail: HSVideoCompositionExportError.failedToExport)
          return
        }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [locationID], options: nil)
        guard let asset = fetchResult.firstObject else {
          strongSelf.delegate?.videoExportManager(didFail: HSVideoCompositionExportError.failedToExport)
          return
        }
        let options = PHVideoRequestOptions()
        options.version = .original
        PHImageManager
          .default()
          .requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, _, _ in
            guard let strongSelf = self else { return }
            guard let urlAsset = avAsset as? AVURLAsset else {
              strongSelf.delegate?.videoExportManager(didFail: HSVideoCompositionExportError.failedToExport)
              return
            }
            strongSelf.delegate?.videoExportManager(didFinishExporting: urlAsset.url)
          }
      }
    }
  }

  func videoExportManager(didFail error: Error) {
    delegate?.videoExportManager(didFail: error)
  }

  func videoExportManager(didUpdateProgress progress: Float) {
    delegate?.videoExportManager(didUpdateProgress: progress)
  }
}
