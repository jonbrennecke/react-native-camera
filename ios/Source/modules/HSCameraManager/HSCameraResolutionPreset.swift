import AVFoundation

@objc
enum HSCameraResolutionPreset : Int {
  @objc(HSCameraResolutionPresetHD720p)
  case hd720p
  @objc(HSCameraResolutionPresetHD1080p)
  case hd1080p
  @objc(HSCameraResolutionPresetHD4K)
  case hd4K
  @objc(HSCameraResolutionPresetVGA)
  case vga
  
  var avCaptureSessionPreset: AVCaptureSession.Preset {
    switch self {
    case .hd4K:
      return .hd4K3840x2160
    case .hd720p:
      return .hd1280x720
    case .hd1080p:
      return .hd1920x1080
    case .vga:
      return .vga640x480
    }
  }
}
