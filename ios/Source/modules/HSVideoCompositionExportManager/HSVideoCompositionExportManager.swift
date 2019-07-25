import Foundation
import Photos

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
      PHPhotoLibrary.shared().performChanges({
        PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
        self.delegate?.videoExportManager(didFinishExporting: url)
      })
    }
  }

  func videoExportManager(didFail error: Error) {
    delegate?.videoExportManager(didFail: error)
  }

  func videoExportManager(didUpdateProgress progress: Float) {
    delegate?.videoExportManager(didUpdateProgress: progress)
  }
}
