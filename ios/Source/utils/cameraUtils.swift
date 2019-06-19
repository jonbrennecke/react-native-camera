import AVFoundation

@available(iOS 11.1, *)
internal func captureDevice(withPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
  if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: position) {
    return device
  }
  if let device = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: position) {
    return device
  }
  let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: position)
  return discoverySession.devices.first
}

@available(iOS 10.0, *)
internal func getOppositeCamera(session: AVCaptureSession) -> AVCaptureDevice? {
  let position = getOppositeCameraPosition(session: session)
  return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
}

// NOTE: defaults to the front camera
fileprivate func getOppositeCameraPosition(session: AVCaptureSession) -> AVCaptureDevice.Position {
  let device = getActiveCaptureDevice(session: session)
  switch device?.position {
  case .some(.back):
    return .front
  case .some(.front):
    return .back
  default:
    return .front
  }
}

fileprivate func getActiveCaptureDevice(session: AVCaptureSession) -> AVCaptureDevice? {
  return session.inputs.reduce(nil) { (device, input) -> AVCaptureDevice? in
    if input.isKind(of: AVCaptureDeviceInput.classForCoder()) {
      let device = (input as! AVCaptureDeviceInput).device
      if isFrontOrBackCamera(device: device) {
        return device
      }
    }
    return device
  }
}

fileprivate func isFrontOrBackCamera(device: AVCaptureDevice) -> Bool {
  return [.back, .front].contains(device.position)
}
