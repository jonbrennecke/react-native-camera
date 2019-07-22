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
      let maskImage = maskImageBuffer.makeCIImage(),
      let cameraImage = cameraImageBuffer.makeCIImage()
    else {
      return nil
    }
    return cameraImage
      .applyingFilter("CIBlendWithMask", parameters: [
        "inputMaskImage": maskImage,
        "inputBackgroundImage": backgroundImage,
      ])
  }
}
