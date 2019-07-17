import CoreImage
import HSCameraUtils

struct HSPortraitMask {
  private let depthBuffer: HSPixelBuffer
  private let cameraBuffer: HSPixelBuffer
  private let maskBuffer: HSPixelBuffer

  public init(depthBuffer: HSPixelBuffer, cameraBuffer: HSPixelBuffer, maskBuffer: HSPixelBuffer) {
    self.depthBuffer = depthBuffer
    self.cameraBuffer = cameraBuffer
    self.maskBuffer = maskBuffer
  }

  public func imageByApplyingMask(toBackground backgroundImage: CIImage) -> CIImage? {
    let maskImageBuffer = HSImageBuffer(pixelBuffer: maskBuffer)
    let cameraImageBuffer = HSImageBuffer(pixelBuffer: cameraBuffer)
    guard
      let maskCGImage = maskImageBuffer.makeImage(),
      let cameraCGImage = cameraImageBuffer.makeImage()
    else {
      return nil
    }
    let cameraCIImage = CIImage(cgImage: cameraCGImage)
    let maskCIImage = CIImage(cgImage: maskCGImage)
    return cameraCIImage
      .applyingFilter("CIBlendWithMask", parameters: [
        "inputMaskImage": maskCIImage,
        "inputBackgroundImage": backgroundImage,
      ])
  }
}
