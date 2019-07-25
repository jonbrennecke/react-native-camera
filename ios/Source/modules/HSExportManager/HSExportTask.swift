import Foundation

@objc
protocol HSExportTaskDelegate {
  func exportTask(didEncounterError _: Error)
  func exportTask(didFinishTask task: HSExportTask, time: CFAbsoluteTime)
  func exportTask(didUpdateProgress progress: Float, time: CFAbsoluteTime)
}

@objc
protocol HSExportTask {
  var delegate: HSExportTaskDelegate? { get set }
  func startTask()
}
