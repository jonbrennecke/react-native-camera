import Foundation

@objc
protocol HSVolumeButtonObserverDelegate: AnyObject {
  @objc(volumeButtonObserverDidChangeVolume:)
  func volumeButtonObserver(didChangeVolume volume: Float)
  @objc(volumeButtonObserverDidEncounterError:)
  func volumeButtonObserver(didEncounterError error: Error)
}
