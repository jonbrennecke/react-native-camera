import AVFoundation
import MediaPlayer

@objc
class HSVolumeButtonObserver: NSObject {
  public weak var delegate: HSVolumeButtonObserverDelegate?

  @objc
  public func startObservingVolumeButton(with volumeDelegate: HSVolumeButtonObserverDelegate) {
    delegate = volumeDelegate
    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(.playAndRecord, options: .mixWithOthers)
      try audioSession.setActive(true, options: [])
      audioSession.addObserver(
        self, forKeyPath:
        #keyPath(AVAudioSession.outputVolume),
        options: [.old, .new],
        context: nil
      )
    } catch {
      delegate?.volumeButtonObserver(didEncounterError: error)
    }
    
    // set initial volume
    let volume = audioSession.outputVolume
    let epsilon = Float(0.001)
    if fabsf(volume - 1.0) < epsilon {
      setVolume(1 - epsilon)
    } else if fabsf(volume - 0.0) < epsilon {
      setVolume(epsilon)
    }
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
      let volume = (change?[.newKey] as? NSNumber)?.floatValue,
      let prevVolume = (change?[.oldKey] as? NSNumber)?.floatValue {
      let epsilon = Float(0.001)
      let twoEpsilon = Float(0.002)

      let difference = fabsf(prevVolume - volume)
      if volume > (1 - twoEpsilon) || volume < twoEpsilon || difference > 0.06 {
        delegate?.volumeButtonObserver(didChangeVolume: volume)
      }

      if fabsf(volume - 1.0) <= epsilon {
        setVolume(1 - twoEpsilon)
      } else if fabsf(volume - 0.0) <= epsilon {
        setVolume(twoEpsilon)
      }
    }
  }

  private func setVolume(_ volume: Float) {
    DispatchQueue.main.async {
      let volumeView = MPVolumeView()
      let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
        slider?.value = volume
      }
    }
  }
}
