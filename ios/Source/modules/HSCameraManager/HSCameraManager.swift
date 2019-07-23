import AVFoundation
import HSCameraUtils
import Photos

fileprivate let DEFAULT_DEPTH_CAPTURE_FRAMES_PER_SECOND = Float64(24)

@available(iOS 11.1, *)
@objc
class HSCameraManager: NSObject {
  private enum State {
    case none
    case stopped(startTime: CMTime, endTime: CMTime)
    case recording(toURL: URL, startTime: CMTime)
    case waitingForFileOutputToFinish(toURL: URL)
  }

  private var state: State = .none
  private let sessionQueue = DispatchQueue(label: "camera session queue")
  private let videoOutput = AVCaptureVideoDataOutput()
  private let videoFileOutput = AVCaptureMovieFileOutput()
  private let depthOutput = AVCaptureDepthDataOutput()
  private let metadataOutput = AVCaptureMetadataOutput()
  private lazy var outputSynchronizer = AVCaptureDataOutputSynchronizer(
    dataOutputs: [depthOutput, videoOutput, metadataOutput]
  )
  private var videoCaptureDevice: AVCaptureDevice?
  private var videoCaptureDeviceInput: AVCaptureDeviceInput?
  private var audioCaptureDevice: AVCaptureDevice?
  private var audioCaptureDeviceInput: AVCaptureDeviceInput?
  private var assetWriter = HSVideoWriter()
  private var assetWriterDepthInput: HSVideoWriterFrameBufferInput?
  private var assetWriterVideoInput: HSVideoWriterFrameBufferInput?

  private lazy var depthDataConverter: HSAVDepthDataToPixelBufferConverter? = {
    guard let size = depthResolution else {
      return nil
    }
    return HSAVDepthDataToPixelBufferConverter(size: size, pixelFormatType: kCVPixelFormatType_OneComponent8)
  }()

  internal var captureSession = AVCaptureSession()

  // kCVPixelFormatType_32BGRA is required because of compatability with depth effects, but
  // if depth is disabled, this should be left as the default YpCbCr
  public var videoPixelFormat: OSType = kCVPixelFormatType_32BGRA {
    didSet {
      // TODO: update video output configuration
    }
  }

  public var depthPixelFormat: OSType = kCVPixelFormatType_DisparityFloat32 {
    didSet {
      // TODO: update depth output configuration
    }
  }

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

  @objc(sharedInstance)
  public static let shared = HSCameraManager()

  @objc
  public var delegate: HSCameraManagerDelegate?

  @objc
  public var depthDelegate: HSCameraManagerDepthDataDelegate?

  private func setupAssetWriter(to outputURL: URL) -> HSCameraSetupResult {
    assetWriter = HSVideoWriter()
    guard
      let depthSize = depthResolution,
      let videoSize = videoResolution
    else {
      return .failure
    }
    assetWriterDepthInput = HSVideoWriterFrameBufferInput(
      videoSize: depthSize,
      pixelFormatType: depthPixelFormat,
      isRealTime: true
    )
    assetWriterDepthInput?.isEnabled = false
    assetWriterVideoInput = HSVideoWriterFrameBufferInput(
      videoSize: videoSize,
      pixelFormatType: videoPixelFormat,
      isRealTime: true
    )
    guard
      case .success = assetWriter.prepareToRecord(to: outputURL),
      let depthInput = assetWriterDepthInput,
      case .success = assetWriter.add(input: depthInput),
      let videoInput = assetWriterVideoInput,
      case .success = assetWriter.add(input: videoInput)
    else {
      return .failure
    }
    return .success
  }

  private func makeEmptyVideoOutputFile() throws -> URL {
    let outputTemporaryDirectoryURL = try FileManager.default
      .url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: FileManager.default.temporaryDirectory, create: true)
    let outputURL = outputTemporaryDirectoryURL
      .appendingPathComponent(makeRandomFileName())
      .appendingPathExtension("mov")
    try? FileManager.default.removeItem(at: outputURL)
    return outputURL
  }

  private func attemptToSetupCameraCaptureSession() -> HSCameraSetupResult {
    let preset: AVCaptureSession.Preset = .vga640x480
    if captureSession.canSetSessionPreset(preset) {
      captureSession.sessionPreset = preset
    }

    videoCaptureDevice = captureDevice(withPosition: .front)
    guard case .some = videoCaptureDevice else {
      return .failure
    }

    if case .failure = setupVideoInput() {
      return .failure
    }

    if case .failure = setupVideoOutput() {
      return .failure
    }

    if case .failure = setupMetadataOutput() {
      return .failure
    }

    if case .failure = setupDepthOutput() {
      return .failure
    }

    configureActiveFormat()
    outputSynchronizer.setDelegate(self, queue: sessionQueue)
    return .success
  }

  private func setupMetadataOutput() -> HSCameraSetupResult {
    if captureSession.canAddOutput(metadataOutput) {
      captureSession.addOutput(metadataOutput)
      metadataOutput.metadataObjectTypes = [.face]
    } else {
      return .failure
    }
    return .success
  }

  private func setupVideoInput() -> HSCameraSetupResult {
    guard let videoCaptureDevice = videoCaptureDevice else {
      return .failure
    }
    videoCaptureDeviceInput = try? AVCaptureDeviceInput(device: videoCaptureDevice)
    guard let videoCaptureDeviceInput = videoCaptureDeviceInput else {
      return .failure
    }
    if captureSession.canAddInput(videoCaptureDeviceInput) {
      captureSession.addInput(videoCaptureDeviceInput)
    } else {
      return .failure
    }
    return .success
  }

  private func setupVideoOutput() -> HSCameraSetupResult {
    videoOutput.alwaysDiscardsLateVideoFrames = false
    videoOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey: videoPixelFormat,
    ] as [String: Any]
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
    depthOutput.alwaysDiscardsLateDepthData = false
    depthOutput.isFilteringEnabled = true
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

  private func configureActiveFormat() {
    guard let videoCaptureDevice = videoCaptureDevice else {
      return
    }
    if case .some = try? videoCaptureDevice.lockForConfiguration() {
      let supportedDepthFormats = videoCaptureDevice.activeFormat.supportedDepthDataFormats

      let depthFormats = supportedDepthFormats.filter { format in
        return CMFormatDescriptionGetMediaSubType(format.formatDescription) == depthPixelFormat
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

  public func focus(on point: CGPoint) {
    guard let device = videoCaptureDevice else {
      return
    }
    if case .some = try? device.lockForConfiguration() {
      // set focus point
      if device.isFocusPointOfInterestSupported {
        device.focusPointOfInterest = point
      }
      if device.isFocusModeSupported(.autoFocus) {
        device.focusMode = .autoFocus
      }

      // set exposure point
      if device.isExposurePointOfInterestSupported {
        device.exposurePointOfInterest = point
      }
      if device.isExposureModeSupported(.continuousAutoExposure) {
        device.exposureMode = .continuousAutoExposure
      }

      device.unlockForConfiguration()
    }
  }

  // MARK: - objc interface

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
  public var supportedISORange: HSMinMaxInterval {
    guard let format = videoCaptureDevice?.activeFormat else {
      return HSMinMaxInterval.zero
    }
    return HSMinMaxInterval(min: format.minISO, max: format.maxISO)
  }

  @objc(setISO:withCompletionHandler:)
  public func setISO(_ iso: Float, _ completionHandler: @escaping () -> Void) {
    guard let videoCaptureDevice = videoCaptureDevice else {
      completionHandler()
      return
    }
    if case .some = try? videoCaptureDevice.lockForConfiguration() {
      let duration = videoCaptureDevice.exposureDuration
      videoCaptureDevice.exposureMode = .custom
      videoCaptureDevice.setExposureModeCustom(duration: duration, iso: iso) { _ in
        completionHandler()
      }
      videoCaptureDevice.unlockForConfiguration()
    } else {
      completionHandler()
    }
  }

  @objc
  public var supportedExposureRange: HSMinMaxInterval {
    guard let videoCaptureDevice = videoCaptureDevice else {
      return HSMinMaxInterval.zero
    }
    return HSMinMaxInterval(
      min: videoCaptureDevice.minExposureTargetBias,
      max: videoCaptureDevice.maxExposureTargetBias
    )
  }

  @objc(setExposure:withCompletionHandler:)
  public func setExposure(_ exposureBias: Float, _ completionHandler: @escaping () -> Void) {
    guard let videoCaptureDevice = videoCaptureDevice else {
      completionHandler()
      return
    }
    if case .some = try? videoCaptureDevice.lockForConfiguration() {
      videoCaptureDevice.exposureMode = .locked
      videoCaptureDevice.setExposureTargetBias(exposureBias) { _ in
        completionHandler()
      }
      videoCaptureDevice.unlockForConfiguration()
    } else {
      completionHandler()
    }
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
        let outputURL = try self.makeEmptyVideoOutputFile()
        guard case .success = self.setupAssetWriter(to: outputURL) else {
          completionHandler(nil, false)
          return
        }
        let clock = CMClockGetHostTimeClock()
        let startTime = CMClockGetTime(clock)
        guard case .success = self.assetWriter.startRecording(at: startTime) else {
          completionHandler(nil, false)
          return
        }
        self.state = .recording(toURL: outputURL, startTime: startTime)
        completionHandler(nil, true)
      } catch {
        completionHandler(error, false)
      }
    }
  }

  @objc(stopCaptureAndSaveToCameraRoll:completionHandler:)
  public func stopCapture(andSaveToCameraRoll _: Bool, _ completionHandler: @escaping (Bool) -> Void) {
    if case let .recording(_, startTime) = state {
      let clock = CMClockGetHostTimeClock()
      let endTime = CMClockGetTime(clock)
      state = .stopped(startTime: startTime, endTime: endTime)
      assetWriterVideoInput?.finish()
      assetWriterDepthInput?.finish()
      assetWriter.stopRecording(at: endTime) { url in
        PHPhotoLibrary.shared().performChanges({
          PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
          completionHandler(true)
        })
      }
    } else {
      completionHandler(false)
    }
  }

  @objc
  public func switchToOppositeCamera() {
    captureSession.beginConfiguration()
    if case .failure = attemptToSwitchToOppositeCamera() {
      // TODO:
    }
    captureSession.commitConfiguration()
  }
}

@available(iOS 11.1, *)
extension HSCameraManager: AVCaptureDataOutputSynchronizerDelegate {
  func dataOutputSynchronizer(
    _: AVCaptureDataOutputSynchronizer, didOutput collection: AVCaptureSynchronizedDataCollection
  ) {
    guard
      let synchronizedDepthData = collection.synchronizedData(for: depthOutput) as? AVCaptureSynchronizedDepthData,
      let synchronizedVideoData = collection.synchronizedData(for: videoOutput) as? AVCaptureSynchronizedSampleBufferData,
      let synchronizedMetadata = collection.synchronizedData(for: metadataOutput) as? AVCaptureSynchronizedMetadataObjectData
    else {
      return
    }

//    var startTime: CMTime?
//    if case let .stopped(time, _) = state {
//      startTime = time
//    }
//
//    if case let .recording(_, startTime) = state {
//      startTime = time
//    }

    if case let .recording(_, startTime) = state {
      // add depth frame
      if let depthBuffer = depthDataConverter?.convert(depthData: synchronizedDepthData.depthData) {
        let presentationTime = synchronizedDepthData.timestamp - startTime
        let frameBuffer = HSVideoFrameBuffer(
          pixelBuffer: depthBuffer, presentationTime: presentationTime
        )
        assetWriterDepthInput?.append(frameBuffer)
      }

      // add video frame
      if let videoBuffer = HSPixelBuffer(sampleBuffer: synchronizedVideoData.sampleBuffer) {
        let presentationTime = synchronizedVideoData.timestamp - startTime
        let frameBuffer = HSVideoFrameBuffer(
          pixelBuffer: videoBuffer, presentationTime: presentationTime
        )
        assetWriterVideoInput?.append(frameBuffer)
      }
    }

    // MARK: - send data to delegates

    if let delegate = depthDelegate {
      if !synchronizedDepthData.depthDataWasDropped {
        delegate.cameraManagerDidOutput(depthData: synchronizedDepthData.depthData)
      }

      if !synchronizedVideoData.sampleBufferWasDropped {
        delegate.cameraManagerDidOutput(videoSampleBuffer: synchronizedVideoData.sampleBuffer)
      }
    }

    // send detected faces to delegate method
    let metadataObjects = synchronizedMetadata.metadataObjects
    let faces = metadataObjects.map { $0 as? AVMetadataFaceObject }.compactMap { $0 }
    delegate?.cameraManagerDidDetect(faces: faces)
  }
}

fileprivate func makeRandomFileName() -> String {
  let random_int = arc4random_uniform(.max)
  return NSString(format: "%x", random_int) as String
}
