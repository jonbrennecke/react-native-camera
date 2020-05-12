import AVFoundation
import ImageUtils
import Photos

private let depthMinFramesPerSecond = Int(20)
private let videoMinFramesPerSecond = Int(20)
private let videoMaxFramesPerSecond = Int(30)

// the max number of concurrent drawables supported by CoreAnimation
private let maxSimultaneousFrames: Int = 3

@available(iOS 11, *)
@objc
class HSCameraManager: NSObject {
  private enum State {
    case none
    case stopped(startTime: CMTime, endTime: CMTime)
    case waitingToRecord(toURL: URL)
    case recording(toURL: URL, startTime: CMTime)
    case waitingForFileOutputToFinish(toURL: URL)
  }

  private(set) var position: AVCaptureDevice.Position = .front
  private(set) var resolutionPreset: HSCameraResolutionPreset = .hd720p
  private(set) var depthEnabled = false
  private let isDebugLogEnabled = false
  private var state: State = .none
  private var paused = false
  private let cameraOutputQueue = DispatchQueue(
    label: "com.jonbrennecke.HSCameraManager.cameraOutputQueue",
    qos: .userInteractive
  )
  private let cameraSetupQueue = DispatchQueue(
    label: "com.jonbrennecke.HSCameraManager.cameraSetupQueue",
    qos: .background
  )
  private let assetWriterQueue = DispatchQueue(
    label: "com.jonbrennecke.HSCameraManager.assetWriterQueue",
    qos: .background
  )
  private var outputSynchronizer: AVCaptureDataOutputSynchronizer?

  // video
  private var videoCaptureDevice: AVCaptureDevice?
  private var videoCaptureDeviceInput: AVCaptureDeviceInput?
  private let videoOutput = AVCaptureVideoDataOutput()
  private let depthOutput = AVCaptureDepthDataOutput()

  // audio
  private var audioCaptureDevice: AVCaptureDevice?
  private var audioCaptureDeviceInput: AVCaptureDeviceInput?
  private let audioOutput = AVCaptureAudioDataOutput()

  // asset writer
  private var assetWriter = VideoWriter()
  private var assetWriterDepthInput: VideoWriterFrameBufferInput?
  private var assetWriterVideoInput: VideoWriterFrameBufferInput?
  private var assetWriterAudioInput: VideoWriterAudioInput?

  private var depthDataConverter: AVDepthDataToPixelBufferConverter?
  private var outputSemaphore = DispatchSemaphore(value: maxSimultaneousFrames)

  private lazy var clock: CMClock = {
    captureSession.masterClock ?? CMClockGetHostTimeClock()
  }()

  internal var audioCaptureSession = AVCaptureSession()
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

  deinit {
    for _ in 0 ..< maxSimultaneousFrames {
      outputSemaphore.signal()
    }
  }

  private func notifyResolutionObservers() {
    resolutionObservers.forEach { observer in
      if !observer.isPaused {
        if let videoResolution = videoResolution {
          observer.cameraManagerDidChange(videoResolution: videoResolution)
        }
        if let depthResolution = depthResolution {
          observer.cameraManagerDidChange(depthResolution: depthResolution)
        }
      }
    }
  }

  private func setupAssetWriter(to outputURL: URL) -> HSCameraSetupResult {
    assetWriter = VideoWriter()
    if depthEnabled, let depthSize = depthResolution {
      assetWriterDepthInput = VideoWriterFrameBufferInput(
        videoSize: depthSize,
        pixelFormatType: kCVPixelFormatType_OneComponent8,
        isRealTime: true
      )
    }
    guard let videoSize = videoResolution else {
      return .failure
    }
    assetWriterVideoInput = VideoWriterFrameBufferInput(
      videoSize: videoSize,
      pixelFormatType: videoPixelFormat,
      isRealTime: true
    )
    assetWriterAudioInput = VideoWriterAudioInput(isRealTime: true)
    // order is important here, if the video track is added first it will be the one visible in Photos app
    guard
      case .success = assetWriter.prepareToRecord(to: outputURL),
      let audioInput = assetWriterAudioInput,
      case .success = assetWriter.add(input: audioInput),
      let videoInput = assetWriterVideoInput,
      case .success = assetWriter.add(input: videoInput)
    else {
      return .failure
    }
    if depthEnabled {
      guard
        let depthInput = assetWriterDepthInput,
        case .success = assetWriter.add(input: depthInput)
      else {
        return .failure
      }
    }
    return .success
  }

  private func setCaptureSessionPreset(withResolutionPreset preset: HSCameraResolutionPreset) {
    let preset: AVCaptureSession.Preset = preset.avCaptureSessionPreset
    if captureSession.canSetSessionPreset(preset) {
      captureSession.sessionPreset = preset
    }
  }

  private func setupVideoCaptureDevice() -> HSCameraSetupResult {
    if #available(iOS 11.1, *) {
      videoCaptureDevice = depthEnabled
        ? depthEnabledCaptureDevice(withPosition: position)
        : captureDevice(withPosition: position)
    } else {
      videoCaptureDevice = captureDevice(withPosition: position)
    }
    return videoCaptureDevice != nil ? .success : .failure
  }

  private func attemptToSetupCameraCaptureSession() -> HSCameraSetupResult {
    setCaptureSessionPreset(withResolutionPreset: resolutionPreset)
    if case .failure = setupVideoCaptureDevice() {
      return .failure
    }

    if case .failure = setupVideoInput() {
      return .failure
    }

    if case .failure = setupVideoOutput() {
      return .failure
    }

    if depthEnabled {
      if case .failure = setupDepthOutput() {
        return .failure
      }
    }

    configureActiveFormat()
    outputSynchronizer = depthEnabled
      ? AVCaptureDataOutputSynchronizer(
        dataOutputs: [videoOutput, depthOutput]
      )
      : AVCaptureDataOutputSynchronizer(
        dataOutputs: [videoOutput]
      )
    outputSynchronizer?.setDelegate(self, queue: DispatchQueue.main)
    return .success
  }

  private func setupVideoInput() -> HSCameraSetupResult {
    guard let videoCaptureDevice = videoCaptureDevice else {
      return .failure
    }
    if case .some = try? videoCaptureDevice.lockForConfiguration() {
      defer {
        videoCaptureDevice.unlockForConfiguration()
      }
      if videoCaptureDevice.isExposureModeSupported(.continuousAutoExposure) {
        videoCaptureDevice.exposureMode = .continuousAutoExposure
      }
    }

    // set up input
    if let previousInput = videoCaptureDeviceInput {
      captureSession.removeInput(previousInput)
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

  private func attemptToSetupAudioCaptureSession() -> HSCameraSetupResult {
    do {
      try audioCaptureDevice?.lockForConfiguration()
      audioCaptureSession.beginConfiguration()
      if case .failure = setupAudioInput(captureSession: audioCaptureSession) {
        return .failure
      }
      setupAudioOutput(captureSession: audioCaptureSession)
      audioOutput.setSampleBufferDelegate(self, queue: cameraOutputQueue)
      audioCaptureSession.commitConfiguration()
      audioCaptureDevice?.unlockForConfiguration()
      return .success
    } catch {
      return .failure
    }
  }

  private func setupAudioOutput(captureSession: AVCaptureSession) {
    if captureSession.canAddOutput(audioOutput) {
      captureSession.addOutput(audioOutput)
      if let connection = audioOutput.connection(with: .audio) {
        connection.isEnabled = true
      }
    }
  }

  private func setupAudioInput(captureSession: AVCaptureSession) -> HSCameraSetupResult {
    audioCaptureDevice = AVCaptureDevice.default(for: .audio)
    guard let audioCaptureDevice = audioCaptureDevice else {
      return .failure
    }
    if let previousInput = audioCaptureDeviceInput {
      captureSession.removeInput(previousInput)
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
        depthPixelFormatTypeRule: depthEnabled ? .oneOf([depthPixelFormat]) : .any,
        depthDimensionsRule: depthEnabled
          ? .greaterThanOrEqualTo(Size<Int>(width: 640, height: 360))
          : .any,
        videoDimensionsRule: .equalTo(resolutionPreset.landscapeSize),
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
      videoCaptureDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(videoMinFramesPerSecond))
      videoCaptureDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(videoMaxFramesPerSecond))
      if #available(iOS 12.0, *) {
        videoCaptureDevice.activeDepthDataMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(depthMinFramesPerSecond))
      }
    }
  }

  private func configureDepthDataConverter() {
    guard let size = depthResolution else {
      return
    }
    depthDataConverter = AVDepthDataToPixelBufferConverter(
      size: size,
      input: depthPixelFormat,
      output: kCVPixelFormatType_OneComponent8,
      bounds: position == .front ? 0.1 ... 5 : 0 ... 0.75
    )
  }

  public func setDepthEnabled(_ depthEnabled: Bool) {
    cameraSetupQueue.async { [weak self] in
      guard let strongSelf = self, depthEnabled != strongSelf.depthEnabled else { return }
      strongSelf.depthEnabled = depthEnabled
      strongSelf.resetCamera()
    }
  }

  public func setResolutionPreset(_ resolutionPreset: HSCameraResolutionPreset) {
    cameraSetupQueue.async { [weak self] in
      guard let strongSelf = self, resolutionPreset != strongSelf.resolutionPreset else { return }
      strongSelf.resolutionPreset = resolutionPreset
      strongSelf.resetCamera()
    }
  }

  public func setPosition(_ position: AVCaptureDevice.Position) {
    cameraSetupQueue.async { [weak self] in
      guard let strongSelf = self, position != strongSelf.position else { return }
      strongSelf.position = position
      strongSelf.resetCamera()
    }
  }

  private func resetCamera() {
    let isRunning = captureSession.isRunning
    if isRunning {
      captureSession.stopRunning()
    }
    try? videoCaptureDevice?.lockForConfiguration()
    defer {
      videoCaptureDevice?.unlockForConfiguration()
    }
    captureSession.beginConfiguration()
    captureSession.inputs.forEach { captureSession.removeInput($0) }
    captureSession.outputs.forEach { captureSession.removeOutput($0) }
    if case .failure = attemptToSetupCameraCaptureSession() {
      print("Failed to set up camera capture session")
    }
    if case .failure = attemptToSetupAudioCaptureSession() {
      print("Failed to set up audio capture session")
    }
    captureSession.commitConfiguration()
    notifyResolutionObservers()
    if isRunning {
      captureSession.startRunning()
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
          device.exposureMode = .autoExpose
        }
      }

      device.unlockForConfiguration()
    }
  }

  // MARK: - objc interface

  private static let requiredPermissions: [PermissionVariant] = [
    .captureDevice(mediaType: .video),
    .captureDevice(mediaType: .audio),
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
  public static func hasSupportedCameraDevice(withPosition position: AVCaptureDevice.Position) -> Bool {
    if #available(iOS 11.1, *) {
      return getDepthEnabledCaptureDevices(withPosition: position).count > 0
    }
    return false
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
  public static func getSupportedFormats(
    depthEnabled: Bool,
    position: AVCaptureDevice.Position
  ) -> [HSCameraFormat] {
    if #available(iOS 11.1, *) {
      let videoCaptureDevice = depthEnabled
        ? depthEnabledCaptureDevice(withPosition: position)
        : captureDevice(withPosition: position)
      return videoCaptureDevice?
        .formats
        .filter { $0.mediaType == .video }
        .map { HSCameraFormat(format: $0) }
        ?? []
    }
    let videoCaptureDevice = captureDevice(withPosition: position)
    return videoCaptureDevice?
      .formats
      .filter { $0.mediaType == .video }
      .map { HSCameraFormat(format: $0) }
      ?? []
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
      if case .failure = strongSelf.attemptToSetupAudioCaptureSession() {
        print("Failed to set up audio capture session")
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
        if !strongSelf.captureSession.isRunning {
          strongSelf.captureSession.startRunning()
          strongSelf.notifyResolutionObservers()
        }
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
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, options: .mixWithOthers)
        try? audioSession.setActive(true, options: [])
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
        strongSelf.assetWriterAudioInput?.finish()
        strongSelf.assetWriterVideoInput?.finish()
        strongSelf.assetWriterDepthInput?.finish()
        let endTime = CMClockGetTime(strongSelf.clock)
        strongSelf.state = .stopped(startTime: startTime, endTime: endTime)
        strongSelf.assetWriter.stopRecording(at: endTime) { url in
          if saveToCameraRoll {
            PHPhotoLibrary.shared().performChanges(
              {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
              },
              completionHandler: { success, _ in
                completionHandler(success, url)
              }
            )
          } else {
            completionHandler(true, url)
          }
        }
        strongSelf.audioCaptureSession.stopRunning()
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

@available(iOS 11.0, *)
extension HSCameraManager: AVCaptureDataOutputSynchronizerDelegate {
  func dataOutputSynchronizer(
    _: AVCaptureDataOutputSynchronizer, didOutput collection: AVCaptureSynchronizedDataCollection
  ) {
    if paused { return }
    _ = outputSemaphore.wait(timeout: .distantFuture)
    defer {
      outputSemaphore.signal()
    }

    let startExecutionTime = CFAbsoluteTimeGetCurrent()
    defer {
      let executionTime = CFAbsoluteTimeGetCurrent() - startExecutionTime
      if isDebugLogEnabled {
        print("[\(String(describing: HSCameraManager.self))]: execution time: \(executionTime)")
      }
    }

    // output depth data
    if let synchronizedDepthData = collection.synchronizedData(for: depthOutput) as? AVCaptureSynchronizedDepthData {
      if !synchronizedDepthData.depthDataWasDropped {
        let orientation: CGImagePropertyOrientation = activeCaptureDevicePosition(session: captureSession) == .some(.front)
          ? .leftMirrored : .right
        let depthData = synchronizedDepthData.depthData.applyingExifOrientation(orientation)
        let disparityPixelBuffer = depthDataConverter?.convert(depthData: depthData)

        startRecordingIfWaiting()
        assetWriterQueue.async { [weak self] in
          guard let strongSelf = self else { return }
          if case .recording = strongSelf.state, let disparityPixelBuffer = disparityPixelBuffer {
            strongSelf.record(disparityPixelBuffer: disparityPixelBuffer, at: synchronizedDepthData.timestamp)
          }
        }

        if let disparityPixelBuffer = disparityPixelBuffer {
          depthDataObservers.forEach {
            $0.cameraManagerDidOutput(
              disparityPixelBuffer: disparityPixelBuffer,
              calibrationData: depthData.cameraCalibrationData
            )
          }
        }
      }
    }

    // output video data
    if let synchronizedVideoData = collection.synchronizedData(for: videoOutput) as? AVCaptureSynchronizedSampleBufferData {
      if !synchronizedVideoData.sampleBufferWasDropped {
        let videoPixelBuffer = PixelBuffer(sampleBuffer: synchronizedVideoData.sampleBuffer)

        if let videoPixelBuffer = videoPixelBuffer {
          depthDataObservers.forEach {
            $0.cameraManagerDidOutput(
              videoPixelBuffer: videoPixelBuffer
            )
          }
        }

        startRecordingIfWaiting()
        assetWriterQueue.async { [weak self] in
          guard let strongSelf = self else { return }
          if case .recording = strongSelf.state, let videoPixelBuffer = videoPixelBuffer {
            strongSelf.record(videoPixelBuffer: videoPixelBuffer, at: synchronizedVideoData.timestamp)
          }
        }
      }

      if let focusPoint = videoCaptureDevice?.focusPointOfInterest {
        depthDataObservers.forEach {
          $0.cameraManagerDidFocus(on: focusPoint)
        }
      }
    }
  }

  private func startRecordingIfWaiting() {
    if case let .waitingToRecord(toURL: url) = state {
      let startTime = CMClockGetTime(clock)
      if case .success = assetWriter.startRecording(at: startTime) {
        audioCaptureSession.usesApplicationAudioSession = true
        audioCaptureSession.automaticallyConfiguresApplicationAudioSession = false
        audioCaptureSession.startRunning()
        state = .recording(toURL: url, startTime: startTime)
      }
    }
  }

  private func record(disparityPixelBuffer: PixelBuffer, at presentationTime: CMTime) {
    let frameBuffer = VideoFrameBuffer(
      pixelBuffer: disparityPixelBuffer, presentationTime: presentationTime
    )
    assetWriterDepthInput?.append(frameBuffer)
  }

  private func record(videoPixelBuffer: PixelBuffer, at presentationTime: CMTime) {
    let frameBuffer = VideoFrameBuffer(
      pixelBuffer: videoPixelBuffer, presentationTime: presentationTime
    )
    assetWriterVideoInput?.append(frameBuffer)
  }

  private func record(audioSampleBuffer sampleBuffer: CMSampleBuffer) {
    assetWriterAudioInput?.append(sampleBuffer)
  }
}

extension HSCameraManager: AVCaptureAudioDataOutputSampleBufferDelegate {
  func captureOutput(
    _: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from _: AVCaptureConnection
  ) {
    startRecordingIfWaiting()
    assetWriterQueue.async { [weak self] in
      guard let strongSelf = self else { return }
      if case .recording = strongSelf.state {
        strongSelf.record(audioSampleBuffer: sampleBuffer)
      }
    }
  }
}
