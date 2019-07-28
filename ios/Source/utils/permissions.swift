import Photos

internal enum PermissionVariant {
  case captureDevice(mediaType: AVMediaType)
  case mediaLibrary
  case microphone
}

internal func requestPermissions(for permissions: [PermissionVariant], _ callback: @escaping (Bool) -> Void) {
  guard let last = permissions.last else {
    callback(true)
    return
  }
  requestPermission(for: last) { success in
    if !success {
      callback(false)
      return
    }
    let nextPermissions = Array(permissions[..<(permissions.count - 1)])
    requestPermissions(for: nextPermissions, callback)
  }
}

fileprivate func requestPermission(for permission: PermissionVariant, _ callback: @escaping (Bool) -> Void) {
  switch permission {
  case let .captureDevice(mediaType: mediaType):
    authorizeCaptureDevice(with: mediaType, callback)
  case .mediaLibrary:
    authorizeMicrophone(callback)
  case .microphone:
    authorizeMicrophone(callback)
  }
}

fileprivate func authorizeCaptureDevice(with mediaType: AVMediaType, _ callback: @escaping (Bool) -> Void) {
  switch AVCaptureDevice.authorizationStatus(for: mediaType) {
  case .authorized:
    return callback(true)
  case .notDetermined:
    AVCaptureDevice.requestAccess(for: mediaType) { granted in
      if granted {
        return callback(true)
      } else {
        return callback(false)
      }
    }
  case .denied:
    return callback(false)
  case .restricted:
    return callback(false)
    @unknown default:
    return callback(false)
  }
}

fileprivate func authorizeMediaLibrary(_ callback: @escaping (Bool) -> Void) {
  PHPhotoLibrary.requestAuthorization { status in
    switch status {
    case .authorized:
      return callback(true)
    case .denied:
      return callback(false)
    case .notDetermined:
      return callback(false)
    case .restricted:
      return callback(false)
      @unknown default:
      return callback(false)
    }
  }
}

fileprivate func authorizeMicrophone(_ callback: @escaping (Bool) -> Void) {
  switch AVCaptureDevice.authorizationStatus(for: .audio) {
  case .authorized:
    return callback(true)
  case .notDetermined:
    AVCaptureDevice.requestAccess(for: .audio) { granted in
      if granted {
        return callback(true)
      } else {
        return callback(false)
      }
    }
  case .denied:
    return callback(false)
  case .restricted:
    return callback(false)
    @unknown default:
    return callback(false)
  }
}

fileprivate func isAuthorized() -> Bool {
  if case .authorized = AVCaptureDevice.authorizationStatus(for: .video),
    case .authorized = AVCaptureDevice.authorizationStatus(for: .audio) {
    return true
  }
  return false
}

internal func permissionStatus(for permissions: [PermissionVariant]) -> Bool {
  return permissions.allSatisfy { permissionStatus(for: $0) }
}

internal func permissionStatus(for permission: PermissionVariant) -> Bool {
  switch permission {
  case .captureDevice(mediaType: .audio):
    return .authorized == AVCaptureDevice.authorizationStatus(for: .audio)
  case .captureDevice(mediaType: .video):
    return .authorized == AVCaptureDevice.authorizationStatus(for: .video)
  case .mediaLibrary:
    return .authorized == PHPhotoLibrary.authorizationStatus()
  case .microphone:
    return .authorized == AVCaptureDevice.authorizationStatus(for: .audio)
  case .captureDevice:
    return false
  }
}
