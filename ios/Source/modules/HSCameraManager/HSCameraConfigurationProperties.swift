import Foundation

@objc
class HSCameraConfigurationProperties: NSObject {
  let resolutionPreset: HSCameraResolutionPreset
  let depthEnabled: Bool

  @objc
  init(resolutionPreset: HSCameraResolutionPreset, depthEnabled: Bool) {
    self.resolutionPreset = resolutionPreset
    self.depthEnabled = depthEnabled
  }
}
