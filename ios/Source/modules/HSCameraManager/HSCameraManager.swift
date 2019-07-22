import AVFoundation
import HSCameraUtils
import Photos

fileprivate let DEFAULT_DEPTH_CAPTURE_FRAMES_PER_SECOND = Float64(24)

@available(iOS 11.1, *)
@objc
class HSCameraManager: NSObject {
  private enum State {
    case stopped
    case recording(toURL: URL, startTime: CMTime)
    case waitingForFileOutputToFinish(toURL: URL)
  }

  private var state: State = .stopped
  private let sessionQueue = DispatchQueue(label: "camera session queue")
  private let videoOutput = AVCaptureVideoDataOutput()
  private let videoFileOutput = AVCaptureMovieFileOutput()
  private let depthOutput = AVCaptureDepthDataOutput()
//  private let metadataInput = AVCaptureMetadataInput()
  private let metadataOutput = AVCaptureMetadataOutput()
  private lazy var outputSynchronizer = AVCaptureDataOutputSynchronizer(
    dataOutputs: [depthOutput, videoOutput, metadataOutput]
  )
  private var videoCaptureDevice: AVCaptureDevice?
  private var videoCaptureDeviceInput: AVCaptureDeviceInput?
  private var audioCaptureDevice: AVCaptureDevice?
  private var audioCaptureDeviceInput: AVCaptureDeviceInput?
  private var assetWriter = HSVideoWriter()

  private lazy var depthDataConverter: HSAVDepthDataToPixelBufferConverter? = {
    guard let size = depthResolution else {
      return nil
    }
    return HSAVDepthDataToPixelBufferConverter(size: size, pixelFormatType: kCVPixelFormatType_OneComponent8)
  }()

  private lazy var assetWriterDepthInput: HSVideoWriterFrameBufferInput? = {
    guard let size = depthResolution else {
      return nil
    }
    return HSVideoWriterFrameBufferInput(
      videoSize: size,
      pixelFormatType: depthPixelFormat,
      isRealTime: true
    )
  }()

  private lazy var assetWriterVideoInput: HSVideoWriterFrameBufferInput? = {
    guard let size = videoResolution else {
      return nil
    }
    return HSVideoWriterFrameBufferInput(
      videoSize: size,
      pixelFormatType: videoPixelFormat,
      isRealTime: true
    )
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
    videoOutput.alwaysDiscardsLateVideoFrames = true
    videoOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey: videoPixelFormat,
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
    depthOutput.isFilteringEnabled = true
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
        guard
          case .success = self.assetWriter.prepareToRecord(to: outputURL),
          let depthInput = self.assetWriterDepthInput,
          case .success = self.assetWriter.add(input: depthInput),
          let videoInput = self.assetWriterVideoInput,
          case .success = self.assetWriter.add(input: videoInput)
        else {
          completionHandler(nil, false)
          return
        }

        guard case .success = self.assetWriter.startRecording() else {
          completionHandler(nil, false)
          return
        }

        let clock = CMClockGetHostTimeClock()
        let startTime = CMClockGetTime(clock)
        self.state = .recording(toURL: outputURL, startTime: startTime)
        completionHandler(nil, true)
      } catch {
        completionHandler(error, false)
      }
    }
  }

  @objc(stopCaptureAndSaveToCameraRoll:completionHandler:)
  public func stopCapture(andSaveToCameraRoll _: Bool, _ completionHandler: (Bool) -> Void) {
    if case let .recording(_, startTime) = state {
      assetWriterVideoInput?.finish()
      assetWriterDepthInput?.finish()
      let clock = CMClockGetHostTimeClock()
      let endTime = CMClockGetTime(clock) - startTime
      assetWriter.stopRecording(at: endTime) { url in
        PHPhotoLibrary.shared().performChanges({
          PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
        })
      }
    }
    state = .stopped
    completionHandler(true)
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

    // frames may be late, check when recording ended
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

//      let objects = synchronizedMetadata.metadataObjects
//      let items = objects.map { object in
//        if object.type == .face {
//          let timeRange = CMTimeRange(start: object.time, duration: object.duration)
//          var item = AVMutableMetadataItem()
//          item.identifier = .quickTimeMetadataDetectedFace
//          item.keySpace = .common
//          item.duration = object.duration
      ////          item.value = object
      ////          item.dataType
//          return item
//        }
//      }
//      let timeRange = CMTimeRange(start: object.time, duration: object.duration)
//      let metadataGroup = AVTimedMetadataGroup(items: [items], timeRange: timeRange)
    }

    if let delegate = depthDelegate {
      if !synchronizedDepthData.depthDataWasDropped {
        delegate.cameraManagerDidOutput(depthData: synchronizedDepthData.depthData)
      }

      if !synchronizedVideoData.sampleBufferWasDropped {
        delegate.cameraManagerDidOutput(videoSampleBuffer: synchronizedVideoData.sampleBuffer)
      }
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
      delegate?.cameraManagerDidFinishFileOutput(toFileURL: fileURL, asset: nil, error: error)
      return
    }
    guard case let .waitingForFileOutputToFinish(toURL: url) = state else {
      delegate?.cameraManagerDidFinishFileOutput(toFileURL: fileURL, asset: nil, error: error)
      return
    }
    PHPhotoLibrary.shared().performChanges({ [weak self] in
      let request = PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
      guard let assetPlaceholder = request?.placeholderForCreatedAsset else {
        self?.delegate?.cameraManagerDidFinishFileOutput(toFileURL: url, asset: nil, error: error)
        return
      }
      self?.delegate?.cameraManagerDidFinishFileOutput(toFileURL: url, asset: assetPlaceholder, error: error)
    })
  }
}

fileprivate func makeRandomFileName() -> String {
  let random_int = arc4random_uniform(.max)
  return NSString(format: "%x", random_int) as String
}
