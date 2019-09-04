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
    case waitingToRecord(toURL: URL)
    case recording(toURL: URL, startTime: CMTime)
    case waitingForFileOutputToFinish(toURL: URL)
  }

  private let isDebugLogEnabled = false
  private var state: State = .none
  private let cameraOutputQueue = DispatchQueue(
    label: "com.jonbrennecke.HSCameraManager.cameraOutputQueue", qos: .background
  )
  private let cameraSetupQueue = DispatchQueue(
    label: "com.jonbrennecke.HSCameraManager.cameraSetupQueue", qos: .background
  )
  private let outputProcessingQueue = DispatchQueue(
    label: "com.jonbrennecke.HSCameraManager.outputProcessingQueue", qos: .background
  )
  private let videoOutput = AVCaptureVideoDataOutput()
  private let videoFileOutput = AVCaptureMovieFileOutput()
  private let depthOutput = AVCaptureDepthDataOutput()
  private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
  private var videoCaptureDevice: AVCaptureDevice?
  private var videoCaptureDeviceInput: AVCaptureDeviceInput?
  private var audioCaptureDevice: AVCaptureDevice?
  private var audioCaptureDeviceInput: AVCaptureDeviceInput?
  private var assetWriter = HSVideoWriter()
  private var assetWriterDepthInput: HSVideoWriterFrameBufferInput?
  private var assetWriterVideoInput: HSVideoWriterFrameBufferInput?
  private var depthDataConverter: HSAVDepthDataToPixelBufferConverter?
  private var outputSemaphore = DispatchSemaphore(value: 1)

  private lazy var clock: CMClock = {
    captureSession.masterClock ?? CMClockGetHostTimeClock()
  }()

  internal var captureSession = AVCaptureSession()
  internal var depthDataObservers = HSObserverCollection<HSCameraDepthDataObserver>()
  internal var resolutionObservers = HSObserverCollection<HSCameraResolutionObserver>()

  // kCVPixelFormatType_32BGRA is required because of compatability with depth effects, but
  // if depth is disabled, this should be left as the default YpCbCr
  public var videoPixelFormat: OSType = kCVPixelFormatType_32BGRA

  public var depthPixelFormat: OSType = kCVPixelFormatType_DisparityFloat32

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
    if let connection = videoOutput.connection(with: .video), connection.videoOrientation == .portrait {
      return Size(width: height, height: width)
    }
    return Size(width: width, height: height)
  }

  @objc(sharedInstance)
  public static let shared = HSCameraManager()

  @objc
  public weak var delegate: HSCameraManagerDelegate?

  private func notifyResolutionObservers() {
    guard
      let videoResolution = videoResolution,
      let depthResolution = depthResolution
    else {
      return
    }
    resolutionObservers.forEach { observer in
      if !observer.isPaused {
        observer.cameraManagerDidChangeResolution(
          videoResolution: videoResolution,
          depthResolution: depthResolution
        )
      }
    }
  }

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
      isRealTime: false
    )
    assetWriterVideoInput = HSVideoWriterFrameBufferInput(
      videoSize: videoSize,
      pixelFormatType: videoPixelFormat,
      isRealTime: false
    )
    // order is important here, if the video track is added first it will be the one visible in Photos app
    guard
      case .success = assetWriter.prepareToRecord(to: outputURL),
      let videoInput = assetWriterVideoInput,
      case .success = assetWriter.add(input: videoInput),
      let depthInput = assetWriterDepthInput,
      case .success = assetWriter.add(input: depthInput)
    else {
      return .failure
    }
    return .success
  }

  private func attemptToSetupCameraCaptureSession() -> HSCameraSetupResult {
    let preset: AVCaptureSession.Preset = .hd1280x720
    if captureSession.canSetSessionPreset(preset) {
      captureSession.sessionPreset = preset
    }

    videoCaptureDevice = depthEnabledCaptureDevice(withPosition: position)
    if case .none = videoCaptureDevice {
      return .failure
    }

    if case .failure = setupVideoInput() {
      return .failure
    }

    if case .failure = setupVideoOutput() {
      return .failure
    }

    if case .failure = setupDepthOutput() {
      return .failure
    }

    configureActiveFormat()
    outputSynchronizer = AVCaptureDataOutputSynchronizer(
      dataOutputs: [videoOutput, depthOutput]
    )
    outputSynchronizer?.setDelegate(self, queue: cameraOutputQueue)
    return .success
  }

  private func setupVideoInput() -> HSCameraSetupResult {
    guard let videoCaptureDevice = videoCaptureDevice else {
      return .failure
    }
    if let previousDevice = videoCaptureDeviceInput {
      captureSession.removeInput(previousDevice)
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
    captureSession.removeOutput(videoOutput)
    videoOutput.alwaysDiscardsLateVideoFrames = false
    videoOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey: videoPixelFormat,
    ] as [String: Any]
    if captureSession.canAddOutput(videoOutput) {
      captureSession.addOutput(videoOutput)
      if let connection = videoOutput.connection(with: .video) {
        connection.isEnabled = true
        if connection.isVideoOrientationSupported {
          connection.videoOrientation = .portrait
        }
        if position == .front, connection.isVideoMirroringSupported {
          connection.isVideoMirrored = true
        }
      }
    } else {
      return .failure
    }
    return .success
  }

  private func setupDepthOutput() -> HSCameraSetupResult {
    if captureSession.outputs.contains(depthOutput) {
      captureSession.removeOutput(depthOutput)
    }
    depthOutput.alwaysDiscardsLateDepthData = false
    depthOutput.isFilteringEnabled = true
    if captureSession.canAddOutput(depthOutput) {
      captureSession.addOutput(depthOutput)
      if let connection = depthOutput.connection(with: .depthData) {
        connection.isEnabled = true
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
      defer {
        videoCaptureDevice.unlockForConfiguration()
        configureDepthDataConverter()
      }
      let searchDescriptor = HSCameraFormatSearchDescriptor(
        depthPixelFormatTypeRule: .oneOf([depthPixelFormat]),
        depthDimensionsRule: position == .front
          ? .greaterThanOrEqualTo(Size<Int>(width: 640, height: 360))
          : .any,
        videoDimensionsRule: position == .front
          ? .equalTo(Size<Int>(width: 1280, height: 720))
          : .equalTo(Size<Int>(width: 640, height: 480)),
        frameRateRule: .greaterThanOrEqualTo(20),
        sortRule: .maximizeFrameRate,
        depthFormatSortRule: .maximizeDimensions
      )
      guard let searchResult = searchDescriptor.search(formats: videoCaptureDevice.formats) else {
        return
      }
      videoCaptureDevice.activeFormat = searchResult.format
      videoCaptureDevice.activeDepthDataFormat = searchResult.depthDataFormat
      videoCaptureDevice.videoZoomFactor = searchResult.format.videoMinZoomFactorForDepthDataDelivery
    }
  }

  private func configureDepthDataConverter() {
    guard let size = depthResolution else {
      return
    }
    depthDataConverter = HSAVDepthDataToPixelBufferConverter(
      size: size,
      input: depthPixelFormat,
      output: kCVPixelFormatType_OneComponent8
    )
  }

  private(set) var position: AVCaptureDevice.Position = .front

  public func setPosition(_ position: AVCaptureDevice.Position) {
    cameraSetupQueue.async { [weak self] in
      guard let strongSelf = self else { return }
      strongSelf.position = position
      strongSelf.captureSession.beginConfiguration()
      strongSelf.captureSession.inputs.forEach { strongSelf.captureSession.removeInput($0) }
      strongSelf.captureSession.outputs.forEach { strongSelf.captureSession.removeOutput($0) }
      if case .failure = strongSelf.attemptToSetupCameraCaptureSession() {
        print("Failed to set up camera capture session")
      }
      strongSelf.captureSession.commitConfiguration()
    }
  }

  public func focus(on point: CGPoint) {
    guard let device = videoCaptureDevice else {
      return
    }
    if case .some = try? device.lockForConfiguration() {
      // set focus point
      if device.isFocusPointOfInterestSupported {
        device.focusPointOfInterest = point
        if device.isFocusModeSupported(.autoFocus) {
          device.focusMode = .autoFocus
        }
      }

      // set exposure point
      if device.isExposurePointOfInterestSupported {
        device.exposurePointOfInterest = point
        if device.isExposureModeSupported(.autoExpose) {
          device.setExposureTargetBias(0)
          device.exposureMode = .autoExpose
        }
      }

      device.unlockForConfiguration()
    }
  }

  // MARK: - objc interface

  private static let requiredPermissions: [PermissionVariant] = [
    .captureDevice(mediaType: .video),
    .microphone,
    .mediaLibrary,
  ]

  @objc
  public static func requestCameraPermissions(_ callback: @escaping (Bool) -> Void) {
    requestPermissions(for: requiredPermissions) { success in
      callback(success)
    }
  }

  @objc
  public static func hasCameraPermissions() -> Bool {
    return permissionStatus(for: requiredPermissions)
  }

  @objc
  public var supportedISORange: HSMinMaxInterval {
    guard let format = videoCaptureDevice?.activeFormat else {
      return HSMinMaxInterval.zero
    }
    return HSMinMaxInterval(min: format.minISO, max: format.maxISO)
  }

  public var iso: Float {
    return videoCaptureDevice?.iso ?? 0
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
      return completionHandler()
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

  public var aperture: Float {
    return videoCaptureDevice?.lensAperture ?? 0
  }

  @objc
  public var format: HSCameraFormat? {
    guard let activeFormat = videoCaptureDevice?.activeFormat else {
      return nil
    }
    return HSCameraFormat(format: activeFormat)
  }

  @objc
  public var depthFormat: HSCameraFormat? {
    guard let activeDepthFormat = videoCaptureDevice?.activeDepthDataFormat else {
      return nil
    }
    return HSCameraFormat(format: activeDepthFormat)
  }

  @objc
  public var supportedFormats: [HSCameraFormat]? {
    guard let videoCaptureDevice = videoCaptureDevice else {
      return nil
    }
    return videoCaptureDevice.formats
      .filter({ $0.mediaType == .video })
      .map({ HSCameraFormat(format: $0) })
  }

  @objc
  public func setFormat(_ format: HSCameraFormat, withDepthFormat depthFormat: HSCameraFormat, completionHandler: @escaping () -> Void) {
    if
      let videoCaptureDevice = videoCaptureDevice,
      let activeFormat = videoCaptureDevice.formats.first(where: { format.isEqual($0) }),
      let activeDepthFormat = activeFormat.supportedDepthDataFormats.first(where: { depthFormat.isEqual($0) }) {
      if case .some = try? videoCaptureDevice.lockForConfiguration() {
        videoCaptureDevice.activeFormat = activeFormat
        videoCaptureDevice.activeDepthDataFormat = activeDepthFormat
        videoCaptureDevice.unlockForConfiguration()
      }
    }
    completionHandler()
  }

  @objc
  public func setupCameraCaptureSession() {
    cameraSetupQueue.async { [weak self] in
      guard let strongSelf = self else { return }
      let isRunning = strongSelf.captureSession.isRunning
      if isRunning {
        strongSelf.captureSession.stopRunning()
      }
      strongSelf.captureSession.beginConfiguration()
      if case .failure = strongSelf.attemptToSetupCameraCaptureSession() {
        print("Failed to set up camera capture session")
      }
      strongSelf.captureSession.commitConfiguration()
      if isRunning {
        strongSelf.captureSession.startRunning()
      }
    }
  }

  @objc
  public func startPreview() {
    cameraSetupQueue.async { [weak self] in
      guard let strongSelf = self else { return }
      if case .authorized = AVCaptureDevice.authorizationStatus(for: .video) {
        guard strongSelf.captureSession.isRunning else {
          strongSelf.captureSession.startRunning()
          strongSelf.notifyResolutionObservers()
          return
        }
        return
      }
    }
  }

  @objc
  public func stopPreview() {
    cameraSetupQueue.async { [weak self] in
      guard let strongSelf = self else { return }
      guard strongSelf.captureSession.isRunning else {
        return
      }
      strongSelf.captureSession.stopRunning()
    }
  }

  @objc(startCaptureWithMetadata:completionHandler:)
  public func startCapture(
    withMetadata metadata: [String: Any]?,
    completionHandler: @escaping (Error?, Bool) -> Void
  ) {
    cameraSetupQueue.async { [weak self] in
      guard let strongSelf = self else { return }
      guard strongSelf.videoCaptureDevice != nil else {
        completionHandler(nil, false)
        return
      }
      do {
        let outputURL = try makeEmptyVideoOutputFile()
        guard case .success = strongSelf.setupAssetWriter(to: outputURL) else {
          completionHandler(nil, false)
          return
        }
        if let metadata = metadata {
          strongSelf.writeMetadata(metadata)
        }
        strongSelf.state = .waitingToRecord(toURL: outputURL)
        strongSelf.notifyResolutionObservers()
        completionHandler(nil, true)
      } catch {
        completionHandler(error, false)
      }
    }
  }

  @objc(stopCaptureAndSaveToCameraRoll:completionHandler:)
  public func stopCapture(
    andSaveToCameraRoll saveToCameraRoll: Bool,
    _ completionHandler: @escaping (Bool, URL?) -> Void
  ) {
    cameraSetupQueue.async { [weak self] in
      guard let strongSelf = self else { return }
      if case let .recording(_, startTime) = strongSelf.state {
        strongSelf.assetWriterVideoInput?.finish()
        strongSelf.assetWriterDepthInput?.finish()
        let endTime = CMClockGetTime(strongSelf.clock)
        strongSelf.state = .stopped(startTime: startTime, endTime: endTime)
        strongSelf.assetWriter.stopRecording(at: endTime) { url in
          if saveToCameraRoll {
            PHPhotoLibrary.shared().performChanges({
              PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
              completionHandler(true, url)
            })
          } else {
            completionHandler(true, url)
          }
        }
      } else {
        completionHandler(false, nil)
      }
    }
  }

  private func writeMetadata(_ metadata: [String: Any]) {
    do {
      let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: .sortedKeys)
      let jsonString = String(data: jsonData, encoding: .ascii)
      let item = AVMutableMetadataItem()
      item.keySpace = AVMetadataKeySpace.quickTimeUserData
      item.key = AVMetadataKey.quickTimeUserDataKeyInformation as NSString
      item.value = jsonString as NSString?
      guard case .success = assetWriter.add(metadataItem: item) else {
        return
      }
    } catch {
      print("Failed to write JSON metadata to asset writer.")
    }
  }
}

@available(iOS 11.1, *)
extension HSCameraManager: AVCaptureDataOutputSynchronizerDelegate {
  func dataOutputSynchronizer(
    _: AVCaptureDataOutputSynchronizer, didOutput collection: AVCaptureSynchronizedDataCollection
  ) {
    outputProcessingQueue.async { [weak self] in
      guard let strongSelf = self else { return }

      _ = strongSelf.outputSemaphore.wait(timeout: .distantFuture)
      defer {
        strongSelf.outputSemaphore.signal()
      }

      let startTime = CFAbsoluteTimeGetCurrent()
      defer {
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        if strongSelf.isDebugLogEnabled {
          print("[\(String(describing: HSCameraManager.self))]: execution time: \(executionTime)")
        }
      }

      let orientation: CGImagePropertyOrientation = activeCaptureDevicePosition(session: strongSelf.captureSession) == .some(.front)
        ? .leftMirrored : .right

      // output depth data
      if let synchronizedDepthData = collection.synchronizedData(for: strongSelf.depthOutput) as? AVCaptureSynchronizedDepthData {
        if !synchronizedDepthData.depthDataWasDropped {
          let depthData = synchronizedDepthData.depthData.applyingExifOrientation(orientation)
          let disparityPixelBuffer = strongSelf.depthDataConverter?.convert(depthData: depthData)
          
          strongSelf.startRecordingFromWaitingState()
          if case let .recording(_, startTime) = strongSelf.state, let disparityPixelBuffer = disparityPixelBuffer {
            let presentationTime = synchronizedDepthData.timestamp - startTime
            strongSelf.record(disparityPixelBuffer: disparityPixelBuffer, at: presentationTime)
          }
          
          if let disparityPixelBuffer = disparityPixelBuffer {
            strongSelf.depthDataObservers.forEach {
              $0.cameraManagerDidOutput(
                disparityPixelBuffer: disparityPixelBuffer,
                calibrationData: depthData.cameraCalibrationData
              )
            }
          }
        }
      }

      // output video data
      if let synchronizedVideoData = collection.synchronizedData(for: strongSelf.videoOutput) as? AVCaptureSynchronizedSampleBufferData {
        if !synchronizedVideoData.sampleBufferWasDropped {
          let videoPixelBuffer = HSPixelBuffer(sampleBuffer: synchronizedVideoData.sampleBuffer)
          
          strongSelf.startRecordingFromWaitingState()
          if case let .recording(_, startTime) = strongSelf.state, let videoPixelBuffer = videoPixelBuffer {
            let presentationTime = synchronizedVideoData.timestamp - startTime
            strongSelf.record(videoPixelBuffer: videoPixelBuffer, at: presentationTime)
          }
          
          if let videoPixelBuffer = videoPixelBuffer {
            strongSelf.depthDataObservers.forEach {
              $0.cameraManagerDidOutput(
                videoPixelBuffer: videoPixelBuffer
              )
            }
          }
        }
      }

      if let focusPoint = strongSelf.videoCaptureDevice?.focusPointOfInterest {
        strongSelf.depthDataObservers.forEach {
          $0.cameraManagerDidFocus(on: focusPoint)
        }
      }
    }
  }
  
  private func startRecordingFromWaitingState() {
    if case let .waitingToRecord(toURL: url) = state {
      let startTime = CMClockGetTime(clock)
      if case .success = assetWriter.startRecording(at: startTime) {
        state = .recording(toURL: url, startTime: startTime)
      }
    }
  }

  private func record(disparityPixelBuffer: HSPixelBuffer, at presentationTime: CMTime) {
    let frameBuffer = HSVideoFrameBuffer(
      pixelBuffer: disparityPixelBuffer, presentationTime: presentationTime
    )
    assetWriterDepthInput?.append(frameBuffer)
  }

  private func record(videoPixelBuffer: HSPixelBuffer, at presentationTime: CMTime) {
    let frameBuffer = HSVideoFrameBuffer(
      pixelBuffer: videoPixelBuffer, presentationTime: presentationTime
    )
    assetWriterVideoInput?.append(frameBuffer)
  }
}
