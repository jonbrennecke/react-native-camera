import Foundation

protocol HSExportManagerDelegate {
  func videoExportManager(didFinishTask _: HSExportTask)
  func videoExportManager(didFail _: Error)
  func videoExportManager(didUpdateProgress _: Float)
}
