import AVFoundation
import MediaPlayer

@objc
class HSVolumeButtonObserver: NSObject {
  public weak var delegate: HSVolumeButtonObserverDelegate?

  private lazy var volumeView = MPVolumeView()

  @objc
  public func startObservingVolumeButton(with volumeDelegate: HSVolumeButtonObserverDelegate) {
    delegate = volumeDelegate
    let audioSession = AVAudioSession.sharedInstance()
    audioSession.addObserver(
      self, forKeyPath:
      #keyPath(AVAudioSession.outputVolume),
      options: [.old, .new],
      context: nil
    )
    do {
      try audioSession.setCategory(.playAndRecord, options: .mixWithOthers)
      try audioSession.setActive(true, options: [])
    } catch {
      delegate?.volumeButtonObserver(didEncounterError: error)
    }

    // set initial volume
    let volume = audioSession.outputVolume
    resetVolume(volume)
  }

  @objc
  public func stopObservingVolumeButton() {
    let audioSession = AVAudioSession.sharedInstance()
    audioSession.removeObserver(self, forKeyPath: #keyPath(AVAudioSession.outputVolume))
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
      let volume = (change?[.newKey] as? NSNumber)?.floatValue {
      if let prevVolume = (change?[.oldKey] as? NSNumber)?.floatValue {
        let difference = fabsf(prevVolume - volume)
        if difference > 0, !isNearlyOne(volume), !isNearlyZero(volume) {
          delegate?.volumeButtonObserver(didChangeVolume: volume)
        }
      }
      resetVolume(volume)
    }
  }

  private func resetVolume(_ volume: Float) {
    if fabsf(volume - 1.0) < volume.ulp { // volume is 1
      setVolume(0.9375)
    } else if fabsf(volume - 0.0) < volume.ulp { // volume is 0
      setVolume(0.0625)
    } else {
      setVolume(volume)
    }
  }

  fileprivate func isNearlyOne(_ value: Float) -> Bool {
    return fabsf(value - 1.0) < value.ulp
  }

  fileprivate func isNearlyZero(_ value: Float) -> Bool {
    return fabsf(value - 0.0) < value.ulp
  }

  private func setVolume(_ volume: Float) {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) { [weak self] in
      guard let strongSelf = self else { return }
      guard let slider = strongSelf.volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider else {
        return
      }
      slider.value = volume
    }
  }
}
