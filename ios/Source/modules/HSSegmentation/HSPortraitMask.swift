import CoreImage
import ImageUtils

struct HSPortraitMask {
  private let depthBuffer: PixelBuffer
  private let cameraBuffer: PixelBuffer
  private let maskBuffer: PixelBuffer

  public init(depthBuffer: PixelBuffer, cameraBuffer: PixelBuffer, maskBuffer: PixelBuffer) {
    self.depthBuffer = depthBuffer
    self.cameraBuffer = cameraBuffer
    self.maskBuffer = maskBuffer
  }

  public func imageByApplyingMask(toBackground backgroundImage: CIImage) -> CIImage? {
    let maskImageBuffer = ImageBuffer(pixelBuffer: maskBuffer)
    let cameraImageBuffer = ImageBuffer(pixelBuffer: cameraBuffer)
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
