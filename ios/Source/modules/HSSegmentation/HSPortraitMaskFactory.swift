import AVFoundation
import ImageUtils

struct HSPortraitMaskFactory {
  private var model: HSSegmentationModel

  private lazy var modelDepthInputPixelBufferPool: CVPixelBufferPool? = {
    guard let size = model.sizeOf(input: .depthImage) else {
      return nil
    }
    return createCVPixelBufferPool(
      size: size, pixelFormatType: kCVPixelFormatType_OneComponent8
    )
  }()

  private lazy var modelCameraInputPixelBufferPool: CVPixelBufferPool? = {
    guard let size = model.sizeOf(input: .cameraImage) else {
      return nil
    }
    return createCVPixelBufferPool(
      size: size, pixelFormatType: kCVPixelFormatType_OneComponent8
    )
  }()

  private lazy var modelOutputPixelBufferPool: CVPixelBufferPool? = {
    guard let size = model.sizeOf(output: .segmentationImage) else {
      return nil
    }
    return createCVPixelBufferPool(
      size: size, pixelFormatType: kCVPixelFormatType_OneComponent8
    )
  }()

  private lazy var cameraCVPixelBufferPool: CVPixelBufferPool? = {
    guard let resolution = HSCameraManager.shared.videoResolution else {
      return nil
    }
    return createCVPixelBufferPool(
      size: resolution, pixelFormatType: kCVPixelFormatType_OneComponent8
    )
  }()

  private lazy var rawDepthCVPixelBufferPool: CVPixelBufferPool? = {
    guard let resolution = HSCameraManager.shared.depthResolution else {
      return nil
    }
    return createCVPixelBufferPool(
      size: resolution, pixelFormatType: kCVPixelFormatType_OneComponent8
    )
  }()

  public init(model: HSSegmentationModel) {
    self.model = model
  }

  public mutating func makePortraitMask(depthData: AVDepthData, videoSampleBuffer: CMSampleBuffer) -> HSPortraitMask? {
    guard
      let cameraBuffer = preprocess(sampleBuffer: videoSampleBuffer),
      let depthBuffer = preprocess(depthData: depthData),
      let modelOutputPixelBufferPool = modelOutputPixelBufferPool,
      let maskBuffer = try? createSegmentationMask(
        model: model,
        colorBuffer: cameraBuffer,
        depthBuffer: depthBuffer,
        pixelBufferPool: modelOutputPixelBufferPool
      )
    else {
      return nil
    }
    return HSPortraitMask(depthBuffer: depthBuffer, cameraBuffer: cameraBuffer, maskBuffer: maskBuffer)
  }

  private mutating func preprocess(sampleBuffer: CMSampleBuffer) -> PixelBuffer? {
    guard
      let modelCameraInputSize = model.sizeOf(input: .cameraImage),
      let modelCameraInputPixelBufferPool = modelCameraInputPixelBufferPool,
      let cameraCVPixelBufferPool = cameraCVPixelBufferPool,
      let colorPixelBuffer = PixelBuffer(sampleBuffer: sampleBuffer)
    else {
      return nil
    }
    guard let grayscalePixelBuffer = convertBGRAPixelBufferToGrayscale(
      pixelBuffer: colorPixelBuffer, pixelBufferPool: cameraCVPixelBufferPool
    ) else {
      return nil
    }
    let imageBuffer = ImageBuffer(pixelBuffer: grayscalePixelBuffer)
    return imageBuffer.resize(
      to: modelCameraInputSize,
      pixelBufferPool: modelCameraInputPixelBufferPool,
      isGrayscale: true
    )?.pixelBuffer
  }

  private mutating func preprocess(depthData: AVDepthData) -> PixelBuffer? {
    guard
      let modelDepthInputSize = model.sizeOf(input: .depthImage),
      let modelDepthInputPixelBufferPool = modelDepthInputPixelBufferPool,
      let rawDepthCVPixelBufferPool = rawDepthCVPixelBufferPool
    else {
      return nil
    }
    let buffer = PixelBuffer(depthData: depthData)
    let iterator: PixelBufferIterator<Float> = buffer.makeIterator()
    let bounds = iterator.bounds()
    guard let depthPixelBuffer = convertDisparityOrDepthPixelBufferToUInt8(
      pixelBuffer: buffer, pixelBufferPool: rawDepthCVPixelBufferPool, bounds: bounds
    ) else {
      return nil
    }
    let imageBuffer = ImageBuffer(pixelBuffer: depthPixelBuffer)
    return imageBuffer.resize(
      to: modelDepthInputSize,
      pixelBufferPool: modelDepthInputPixelBufferPool,
      isGrayscale: true
    )?.pixelBuffer
  }
}
