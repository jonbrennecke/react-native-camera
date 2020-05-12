import AVFoundation
import ImageUtils

@objc
public final class HSCameraFormat: NSObject {
  let dimensions: Size<Int>
  let mediaType: CMMediaType
  let mediaSubType: FourCharCode
  let supportedFrameRates: [HSMinMaxInterval]
  let supportedDepthFormats: [HSCameraFormat]

  public init(
    dimensions: Size<Int>,
    mediaType: CMMediaType,
    mediaSubType: FourCharCode,
    supportedFrameRates: [HSMinMaxInterval],
    supportedDepthFormats: [HSCameraFormat]
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
    let depthFormats = format.supportedDepthDataFormats.map { HSCameraFormat(format: $0) }
    self.init(
      dimensions: Size(width: Int(dimensions.width), height: Int(dimensions.height)),
      mediaType: mediaType,
      mediaSubType: mediaSubType,
      supportedFrameRates: frameRates,
      supportedDepthFormats: depthFormats
    )
  }

  public func isEqual(_ format: AVCaptureDevice.Format) -> Bool {
    let formatDescription = format.formatDescription
    let formatMediaType = CMFormatDescriptionGetMediaType(formatDescription)
    let formatMediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
    let formatDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
    return formatMediaType == mediaType
      && formatMediaSubType == mediaSubType
      && Int(formatDimensions.height) == dimensions.height
      && Int(formatDimensions.width) == dimensions.width
  }
}

extension HSCameraFormat: FromDictionary {
  public static func from(dictionary: [String: Any]) -> HSCameraFormat? {
    guard
      let dimensionsDict = dictionary["dimensions"] as? [String: Any],
      let dimensions = Size<Int>.from(dictionary: dimensionsDict),
      let mediaTypeString = dictionary["mediaType"] as? String,
      let mediaType = fourCharCode(fromString: mediaTypeString),
      let mediaSubTypeString = dictionary["mediaSubType"] as? String,
      let mediaSubType = fourCharCode(fromString: mediaSubTypeString),
      let supportedFrameRatesArray = dictionary["supportedFrameRates"] as? [[String: Any]],
      let supportedFrameRates = Array<HSMinMaxInterval>.from(arrayOfDictionaries: supportedFrameRatesArray),
      let supportedDepthFormatsArray = dictionary["supportedDepthFormats"] as? [[String: Any]],
      let supportedDepthFormats = Array<HSCameraFormat>.from(arrayOfDictionaries: supportedDepthFormatsArray)
    else {
      return nil
    }
    return HSCameraFormat(
      dimensions: dimensions,
      mediaType: mediaType,
      mediaSubType: mediaSubType,
      supportedFrameRates: supportedFrameRates,
      supportedDepthFormats: supportedDepthFormats
    )
  }
}

extension HSCameraFormat: FromNSDictionary {
  public static func from(dictionary: NSDictionary) -> FromNSDictionary? {
    guard let swiftDict = dictionary as? [String: Any] else {
      return nil
    }
    return from(dictionary: swiftDict)
  }
}

extension HSCameraFormat: ToDictionary, ToNSDictionary {
  public func toDictionary() -> [String: Any] {
    return [
      "dimensions": [
        "height": dimensions.height,
        "width": dimensions.width,
      ],
      "mediaType": string(fromFourCharCode: mediaType),
      "mediaSubType": string(fromFourCharCode: mediaSubType),
      "supportedFrameRates": supportedFrameRates.map { $0.asDictionary() },
      "supportedDepthFormats": supportedDepthFormats.map { $0.asDictionary() },
    ]
  }

  public func toNSDictionary() -> NSDictionary {
    return toDictionary() as NSDictionary
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

private func string(fromFourCharCode code: FourCharCode) -> String {
  let cString: [CChar] = [
    CChar(code >> 24 & 0xFF),
    CChar(code >> 16 & 0xFF),
    CChar(code >> 8 & 0xFF),
    CChar(code & 0xFF),
    0,
  ]
  return String(cString: cString)
}

// See: https://gist.github.com/patrickjuchli/d1b07f97e0ea1da5db09
private func fourCharCode(fromString string: String) -> FourCharCode? {
  var code: FourCharCode = 0
  if string.count == 4, string.utf8.count == 4 {
    for byte in string.utf8 {
      code = code << 8 + FourCharCode(byte)
    }
    return code
  }
  return nil
}
