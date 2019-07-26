import AVFoundation
import HSCameraUtils

@objc
public class HSCameraFormat: NSObject {
  let dimensions: Size<Int>
  let mediaType: CMMediaType
  let mediaSubType: FourCharCode
  let supportedFrameRates: [HSMinMaxInterval]
  let supportedDepthFormats: [HSFormatInfo]

  public init(
    dimensions: Size<Int>,
    mediaType: CMMediaType,
    mediaSubType: FourCharCode,
    supportedFrameRates: [HSMinMaxInterval],
    supportedDepthFormats: [HSFormatInfo]
  ) {
    self.dimensions = dimensions
    self.mediaType = mediaType
    self.mediaSubType = mediaSubType
    self.supportedFrameRates = supportedFrameRates
    self.supportedDepthFormats = supportedDepthFormats
  }

  public convenience init(format: AVCaptureDevice.Format) {
    let formatDescription = format.formatDescription
    let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
    let mediaType = CMFormatDescriptionGetMediaType(formatDescription)
    let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
    let frameRates = format.videoSupportedFrameRateRanges.map {
      HSMinMaxInterval(min: Float($0.minFrameRate), max: Float($0.maxFrameRate))
    }
    let depthFormats = format.supportedDepthDataFormats.map { HSFormatInfo(format: $0) }
    self.init(
      dimensions: Size(width: Int(dimensions.width), height: Int(dimensions.height)),
      mediaType: mediaType,
      mediaSubType: mediaSubType,
      supportedFrameRates: frameRates,
      supportedDepthFormats: depthFormats
    )
  }
}

extension HSCameraFormat: NSDictionaryConvertible {
  @objc
  public func asDictionary() -> NSDictionary {
    return [
      "dimensions": [
        "height": dimensions.height,
        "width": dimensions.width,
      ],
      "mediaType": string(fromFourCharCode: mediaType),
      "mediaSubType": string(fromFourCharCode: mediaSubType),
      "supportedFrameRates": supportedFrameRates.map { $0.asDictionary() },
      "supportedDepthFormats": supportedDepthFormats.map { $0.asDictionary() },
    ] as NSDictionary
  }
}

fileprivate func string(fromFourCharCode code: FourCharCode) -> String {
  let cString: [CChar] = [
    CChar(code >> 24 & 0xFF),
    CChar(code >> 16 & 0xFF),
    CChar(code >> 8 & 0xFF),
    CChar(code & 0xFF),
    0,
  ]
  return String(cString: cString)
}
