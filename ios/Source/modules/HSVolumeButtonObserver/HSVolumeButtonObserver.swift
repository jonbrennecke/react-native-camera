import AVFoundation

@objc
class HSVolumeButtonObserver: NSObject {
  public weak var delegate: HSVolumeButtonObserverDelegate?

  @objc
  public func startObservingVolumeButton(with volumeDelegate: HSVolumeButtonObserverDelegate) {
    delegate = volumeDelegate
    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setActive(true, options: [])
      audioSession.addObserver(
        self, forKeyPath:
        #keyPath(AVAudioSession.outputVolume),
        options: .new,
        context: nil
      )
    } catch {
      delegate?.volumeButtonObserver(didEncounterError: error)
    }
  }

  @objc
  public func stopObservingVolumeButton() {
    delegate = nil
  }

  override func observeValue(
    forKeyPath keyPath: String?,
    of _: Any?,
    change: [NSKeyValueChangeKey: Any]?,
    context _: UnsafeMutableRawPointer?
  ) {
    if
      keyPath == #keyPath(AVAudioSession.outputVolume),
      let volume = change?[.newKey] as? NSNumber {
      delegate?.volumeButtonObserver(didChangeVolume: volume.floatValue)
    }
  }
}
