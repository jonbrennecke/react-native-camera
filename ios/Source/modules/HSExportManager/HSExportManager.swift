import Foundation

class HSExportManager {
  private enum State {
    case ready
    case pending(HSExportTask)
  }

  private var state: State = .ready

  public var delegate: HSExportManagerDelegate?

  public func export(task: HSExportTask) {
    task.delegate = self
    task.startTask()
    state = .pending(task)
  }
}

extension HSExportManager: HSExportTaskDelegate {
  func exportTask(didEncounterError error: Error) {
    delegate?.videoExportManager(didFail: error)
  }

  func exportTask(didFinishTask task: HSExportTask, time _: CFAbsoluteTime) {
    delegate?.videoExportManager(didFinishTask: task)
  }

  func exportTask(didUpdateProgress progress: Float, time _: CFAbsoluteTime) {
    delegate?.videoExportManager(didUpdateProgress: progress)
  }
}
