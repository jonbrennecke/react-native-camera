import AVFoundation

class HSVideoCompositionExportTask: HSExportTask {
  public enum TaskError: Error {
    case failedToCreateAVComposition
    case unknownError
  }

  private let composition: HSVideoComposition
  private var assetExportSession: AVAssetExportSession?
  private var timer: Timer?

  public var delegate: HSExportTaskDelegate?

  public var outputURL: URL? {
    return assetExportSession?.outputURL
  }

  public init(composition: HSVideoComposition) {
    self.composition = composition
  }

  func startTask() {
    timer = startTimer()
    guard let (avComposition, avVideoComposition) = composition.makeAVComposition() else {
      delegate?.exportTask(didEncounterError: TaskError.failedToCreateAVComposition)
      return
    }
    assetExportSession = AVAssetExportSession(
      asset: avComposition, presetName: AVAssetExportPresetHighestQuality
    )
    assetExportSession?.videoComposition = avVideoComposition
    if let compositor = assetExportSession?.customVideoCompositor as? HSVideoCompositor {
      compositor.depthTrackID = composition.depthTrackID
      compositor.videoTrackID = composition.videoTrackID
      compositor.aperture = composition.aperture
      compositor.isPortraitModeEnabled = true // TODO:
    }
    assetExportSession?.outputFileType = .mov
    assetExportSession?.outputURL = try? makeEmptyVideoOutputFile()
    assetExportSession?.exportAsynchronously {
      self.handleExportCompletion()
    }
  }

  private func handleExportCompletion() {
    guard let session = assetExportSession else {
      delegate?.exportTask(didEncounterError: TaskError.unknownError)
      return
    }
    switch session.status {
    case .failed:
      delegate?.exportTask(didEncounterError: session.error!)
    case .completed:
      if let url = session.outputURL {
        completeExport(exportFileURL: url)
        return
      }
      delegate?.exportTask(didEncounterError: TaskError.unknownError)
    default:
      delegate?.exportTask(didEncounterError: TaskError.unknownError)
    }
  }

  private func completeExport(exportFileURL _: URL) {
    delegate?.exportTask(didFinishTask: self, time: CFAbsoluteTimeGetCurrent())
    if let timer = timer {
      stop(timer: timer)
    }
  }

  private func startTimer() -> Timer {
    let timer = Timer(timeInterval: 0.1, target: self, selector: #selector(onExportSessionProgressDidUpdate), userInfo: nil, repeats: true)
    DispatchQueue.main.async {
      RunLoop.current.add(timer, forMode: .common)
    }
    return timer
  }

  private func stop(timer: Timer) {
    timer.invalidate()
  }

  @objc
  private func onExportSessionProgressDidUpdate() {
    guard let progress = assetExportSession?.progress else {
      return
    }
    delegate?.exportTask(didUpdateProgress: progress, time: CFAbsoluteTimeGetCurrent())
  }
}
