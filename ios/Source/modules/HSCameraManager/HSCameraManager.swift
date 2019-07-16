import AVFoundation
import Photos
import HSCameraUtils

fileprivate let DEFAULT_DEPTH_CAPTURE_FRAMES_PER_SECOND = Float64(24)

@available(iOS 11.1, *)
@objc
class HSCameraManager: NSObject {
  internal var captureSession = AVCaptureSession()

  private let sessionQueue = DispatchQueue(label: "session queue")
  private let videoOutput = AVCaptureVideoDataOutput()
  private let videoFileOutput = AVCaptureMovieFileOutput()
  private let depthOutput = AVCaptureDepthDataOutput()

  private lazy var outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [depthOutput, videoOutput])

  private var videoCaptureDevice: AVCaptureDevice?
  private var videoCaptureDeviceInput: AVCaptureDeviceInput?
  private var audioCaptureDevice: AVCaptureDevice?
  private var audioCaptureDeviceInput: AVCaptureDeviceInput?

  @objc(sharedInstance)
  public static let shared = HSCameraManager()

  @objc
  public var delegate: HSCameraManagerDelegate?

  @objc
  public var depthDelegate: HSCameraManagerDepthDataDelegate?
  
  public var videoResolution: Size<Int>? {
    guard let format = videoCaptureDevice?.activeFormat else {
      return nil
    }
    let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
    let width = Int(dimensions.width)
    let height = Int(dimensions.height)
    if let connection = videoOutput.connection(with: .video), connection.videoOrientation == .portrait {
      return Size(width: height, height: width)
    }
    return Size(width: width, height: height)
  }
  
  public var depthResolution: Size<Int>? {
    guard let format = videoCaptureDevice?.activeDepthDataFormat else {
      return nil
    }
    let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
    let width = Int(dimensions.width)
    let height = Int(dimensions.height)
    if let connection = depthOutput.connection(with: .depthData), connection.videoOrientation == .portrait {
      return Size(width: height, height: width)
    }
    return Size(width: width, height: height)
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
    if case .failure = attemptToSetupCameraCaptureSession() {
      // TODO:
    }
    captureSession.commitConfiguration()
  }

  private func attemptToSetupCameraCaptureSession() -> HSCameraSetupResult {
    let preset: AVCaptureSession.Preset = .vga640x480
    if captureSession.canSetSessionPreset(preset) {
      captureSession.sessionPreset = preset
    }

    // Setup videoCaptureDevice
    videoCaptureDevice = captureDevice(withPosition: .front)
    guard let videoCaptureDevice = videoCaptureDevice else {
      return .failure
    }

    // Setup videoCaptureDeviceInput
    videoCaptureDeviceInput = try? AVCaptureDeviceInput(device: videoCaptureDevice)
    guard let videoCaptureDeviceInput = videoCaptureDeviceInput else {
      return .failure
    }
    if captureSession.canAddInput(videoCaptureDeviceInput) {
      captureSession.addInput(videoCaptureDeviceInput)
    } else {
      return .failure
    }

    if case .failure = setupVideoOutput() {
      return .failure
    }

    if case .failure = setupDepthOutput() {
      return .failure
    }

    // Set depth format of videoCaptureDevice
    // TODO: only required if capturing depth
    let selectedDepthFormat = kCVPixelFormatType_DisparityFloat32
    if case .some = try? videoCaptureDevice.lockForConfiguration() {
      let supportedDepthFormats = videoCaptureDevice.activeFormat.supportedDepthDataFormats

      let depthFormats = supportedDepthFormats.filter { format in
        return CMFormatDescriptionGetMediaSubType(format.formatDescription) == selectedDepthFormat
      }

      let highestResolutionDepthFormat = depthFormats.max { a, b in
        CMVideoFormatDescriptionGetDimensions(a.formatDescription).width < CMVideoFormatDescriptionGetDimensions(b.formatDescription).width
      }

      if let format = highestResolutionDepthFormat {
        videoCaptureDevice.activeDepthDataFormat = format
        let maxFrameRateRange = format.videoSupportedFrameRateRanges.max { $0.maxFrameRate < $1.maxFrameRate }
        let depthFrameDuration = CMTimeMake(
          value: 1,
          timescale: CMTimeScale(maxFrameRateRange?.maxFrameRate ?? DEFAULT_DEPTH_CAPTURE_FRAMES_PER_SECOND)
        )
        videoCaptureDevice.activeDepthDataMinFrameDuration = depthFrameDuration
      }

      videoCaptureDevice.unlockForConfiguration()
    }

    outputSynchronizer.setDelegate(self, queue: sessionQueue)

//    TODO: adding this breaks the depth output synchronizer
    // setup videoFileOutput
//    if captureSession.canAddOutput(videoFileOutput) {
//      captureSession.addOutput(videoFileOutput)
//    } else {
//      return .failure
//    }

    return .success
  }

  private func setupVideoOutput() -> HSCameraSetupResult {
    videoOutput.alwaysDiscardsLateVideoFrames = true
    videoOutput.videoSettings = [
      // kCVPixelFormatType_32BGRA is required because of effects
      kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
    ] as [String: Any]
    videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
    if captureSession.canAddOutput(videoOutput) {
      captureSession.addOutput(videoOutput)
      if let connection = videoOutput.connection(with: .video) {
        connection.isEnabled = true
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
    return .success
  }

  private func setupDepthOutput() -> HSCameraSetupResult {
    depthOutput.alwaysDiscardsLateDepthData = true
    depthOutput.isFilteringEnabled = false
    depthOutput.setDelegate(self, callbackQueue: sessionQueue)
    if captureSession.canAddOutput(depthOutput) {
      captureSession.addOutput(depthOutput)
      if let connection = depthOutput.connection(with: .depthData) {
        connection.isEnabled = true
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
}

@available(iOS 11.1, *)
extension HSCameraManager: AVCaptureDataOutputSynchronizerDelegate {
  func dataOutputSynchronizer(_: AVCaptureDataOutputSynchronizer, didOutput collection: AVCaptureSynchronizedDataCollection) {
    guard
      let delegate = depthDelegate,
      let synchronizedDepthData = collection.synchronizedData(for: depthOutput) as? AVCaptureSynchronizedDepthData,
      let synchronizedVideoData = collection.synchronizedData(for: videoOutput) as? AVCaptureSynchronizedSampleBufferData
    else {
      return
    }

    if !synchronizedDepthData.depthDataWasDropped {
      delegate.cameraManagerDidOutput(depthData: synchronizedDepthData.depthData)
    }

    if !synchronizedVideoData.sampleBufferWasDropped {
      delegate.cameraManagerDidOutput(videoSampleBuffer: synchronizedVideoData.sampleBuffer)
    }
  }
}

@available(iOS 11.1, *)
extension HSCameraManager: AVCaptureDepthDataOutputDelegate {
  func depthDataOutput(_: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp _: CMTime, connection _: AVCaptureConnection) {
//    Unused
  }
}

@available(iOS 11.1, *)
extension HSCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
    delegate?.cameraManagerDidReceiveCameraDataOutput(videoData: sampleBuffer)
  }
}

@available(iOS 11.1, *)
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
