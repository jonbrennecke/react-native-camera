import AVFoundation
import Photos

@available(iOS 10.0, *)
@objc
class HSCameraManager: NSObject {
  private var captureSession: AVCaptureSession
  private var videoOutput: AVCaptureVideoDataOutput
  private var videoFileOutput: AVCaptureMovieFileOutput = AVCaptureMovieFileOutput()
  private var videoCaptureDevice: AVCaptureDevice?
  private var videoCaptureDeviceInput: AVCaptureDeviceInput?
  private var audioCaptureDevice: AVCaptureDevice?
  private var audioCaptureDeviceInput: AVCaptureDeviceInput?
  private let sessionQueue = DispatchQueue(label: "session queue")

  @objc(sharedInstance)
  public static let shared = HSCameraManager()

  @objc
  public var delegate: HSCameraManagerDelegate?

  @objc
  public var previewLayer: AVCaptureVideoPreviewLayer

  override init() {
    captureSession = AVCaptureSession()
    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.videoGravity = .resizeAspectFill
    videoOutput = AVCaptureVideoDataOutput()
    super.init()
  }

  @objc
  public static func requestCameraPermissions(_ callback: @escaping (Bool) -> Void) {
    requestPermissions(for: [
      .captureDevice(mediaType: .video),
      .microphone,
      .mediaLibrary,
    ]) { success in
      callback(success)
    }
  }

  @objc
  public func startPreview() {
    if case .authorized = AVCaptureDevice.authorizationStatus(for: .video) {
      guard captureSession.isRunning else {
        captureSession.startRunning()
        return
      }
      return
    }
  }

  @objc
  public func stopPreview() {
    guard captureSession.isRunning else {
      return
    }
    captureSession.stopRunning()
  }

  @objc
  public func startCapture(completionHandler: @escaping (Error?, Bool) -> Void) {
    sessionQueue.async {
      guard self.videoCaptureDevice != nil else {
        completionHandler(nil, false)
        return
      }
      do {
        let outputURL = try self.saveVideoFileOutputOrThrow()
        self.videoFileOutput.stopRecording()
        self.videoFileOutput.startRecording(to: outputURL, recordingDelegate: self)
        completionHandler(nil, true)
      } catch {
        completionHandler(error, false)
      }
    }
  }

  @objc
  public func stopCapture() {
    if videoFileOutput.isRecording {
      videoFileOutput.stopRecording()
    }
  }

  private func saveVideoFileOutputOrThrow() throws -> URL {
    let outputURL = try FileManager.default
      .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      .appendingPathComponent("output")
      .appendingPathExtension("mov")
    try? FileManager.default.removeItem(at: outputURL)
    return outputURL
  }

  @objc
  public func setupCameraCaptureSession() {
    if captureSession.isRunning {
      return
    }
    captureSession.beginConfiguration()
    NotificationCenter.default.addObserver(self, selector: #selector(captureSessionRuntimeError), name: .AVCaptureSessionRuntimeError, object: captureSession)
    if case .failure = attemptToSetupCameraCaptureSession() {
      // TODO:
    }
    captureSession.commitConfiguration()
  }

  @objc
  private func captureSessionRuntimeError(error _: Error) {
    // TODO:
  }

  private func attemptToSetupCameraCaptureSession() -> HSCameraSetupResult {
    if captureSession.canSetSessionPreset(.high) {
      captureSession.sessionPreset = .high
    }

    // setup videoCaptureDevice
    videoCaptureDevice = captureDevice(withPosition: .front)
    guard let videoCaptureDevice = videoCaptureDevice else {
      return .failure
    }
    if videoCaptureDevice.isFocusModeSupported(.autoFocus) {
      videoCaptureDevice.focusMode = .autoFocus
    }

    // setup videoCaptureDeviceInput
    videoCaptureDeviceInput = try? AVCaptureDeviceInput(device: videoCaptureDevice)
    guard let videoCaptureDeviceInput = videoCaptureDeviceInput else {
      return .failure
    }
    if captureSession.canAddInput(videoCaptureDeviceInput) {
      captureSession.addInput(videoCaptureDeviceInput)
    } else {
      return .failure
    }

    if case .failure = setupAudioInput() {
      return .failure
    }

    // setup videoOutput
    videoOutput.alwaysDiscardsLateVideoFrames = true
    videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
    if captureSession.canAddOutput(videoOutput) {
      captureSession.addOutput(videoOutput)
      if let connection = videoOutput.connection(with: .video) {
        if connection.isVideoStabilizationSupported {
          connection.preferredVideoStabilizationMode = .auto
        }
        if connection.isVideoOrientationSupported {
          connection.videoOrientation = .portrait
        }
      }
    } else {
      return .failure
    }

    // setup videoFileOutput
    if captureSession.canAddOutput(videoFileOutput) {
      captureSession.addOutput(videoFileOutput)
    } else {
      return .failure
    }
    return .success
  }

  private func setupAudioInput() -> HSCameraSetupResult {
    audioCaptureDevice = AVCaptureDevice.default(for: .audio)
    guard let audioCaptureDevice = audioCaptureDevice else {
      return .failure
    }

    // setup audioCaptureDeviceInput
    audioCaptureDeviceInput = try? AVCaptureDeviceInput(device: audioCaptureDevice)
    guard let audioCaptureDeviceInput = audioCaptureDeviceInput else {
      return .failure
    }
    if captureSession.canAddInput(audioCaptureDeviceInput) {
      captureSession.addInput(audioCaptureDeviceInput)
    } else {
      return .failure
    }
    return .success
  }

  private func captureDevice(withPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
      return device
    }
    let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: position)
    return discoverySession.devices.first
  }

  @objc
  public func switchToOppositeCamera() {
    captureSession.beginConfiguration()
    if case .failure = attemptToSwitchToOppositeCamera() {
      // TODO:
    }
    captureSession.commitConfiguration()
  }

  private func attemptToSwitchToOppositeCamera() -> HSCameraSetupResult {
    guard let device = getOppositeCamera(session: captureSession) else {
      return .failure
    }
    captureSession.inputs.forEach { input in
      if input.isEqual(audioCaptureDeviceInput) {
        return
      }
      captureSession.removeInput(input)
    }
    guard let deviceInput = try? AVCaptureDeviceInput(device: device) else {
      return .failure
    }
    if captureSession.canAddInput(deviceInput) {
      captureSession.addInput(deviceInput)
    } else {
      return .failure
    }
    videoCaptureDevice = device
    videoCaptureDeviceInput = deviceInput
    return .success
  }

  @objc
  public func focusOnPoint(_ focusPointInLayerCoords: CGPoint) {
    guard let device = videoCaptureDevice else {
      return
    }
    let focusPointInDeviceCoords = previewLayer.captureDevicePointConverted(fromLayerPoint: focusPointInLayerCoords)
    do {
      try device.lockForConfiguration()
      if device.isFocusModeSupported(.autoFocus) {
        device.focusMode = .autoFocus
      }
      if device.isFocusPointOfInterestSupported {
        device.focusPointOfInterest = focusPointInDeviceCoords
      }
      if device.isExposureModeSupported(.continuousAutoExposure) {
        device.exposureMode = .continuousAutoExposure
      }
      if device.isExposurePointOfInterestSupported {
        device.exposurePointOfInterest = focusPointInDeviceCoords
      }
      device.unlockForConfiguration()
    } catch {
      // TODO: handle error
    }
  }
}

@available(iOS 10.0, *)
extension HSCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
    delegate?.cameraManagerDidReceiveCameraDataOutput(videoData: sampleBuffer)
  }
}

@available(iOS 10.0, *)
extension HSCameraManager: AVCaptureFileOutputRecordingDelegate {
  func fileOutput(_: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from _: [AVCaptureConnection]) {
    delegate?.cameraManagerDidBeginFileOutput(toFileURL: fileURL)
  }

  func fileOutput(_: AVCaptureFileOutput, didFinishRecordingTo fileURL: URL, from _: [AVCaptureConnection], error: Error?) {
    if error != nil {
      // TODO: handle error
      return
    }
//    TODO: file output
//    createVideoAsset(forURL: fileURL) { error, _, assetPlaceholder in
//      self.delegate?.cameraManagerDidFinishFileOutput(toFileURL: fileURL, asset: assetPlaceholder, error: error)
//    }
  }
}
