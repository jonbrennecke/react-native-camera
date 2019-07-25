import Foundation

@objc
protocol HSVideoCompositionExportManagerDelegate {
  @objc(videoExportManagerDidFinishExporting:)
  func videoExportManager(didFinishExporting _: URL)
  @objc(videoExportManagerDidFailWithError:)
  func videoExportManager(didFail _: Error)
  @objc(videoExportManagerDidDidUpdateProgress:)
  func videoExportManager(didUpdateProgress _: Float)
}
