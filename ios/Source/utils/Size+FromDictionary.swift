import HSCameraUtils

extension Size: FromDictionary {
  public static func from(dictionary: Dictionary<String, Any>) -> Size? {
    guard
      let height = dictionary["height"] as? T,
      let width = dictionary["width"] as? T
    else {
      return nil
    }
    return Size(width: width, height: height)
  }
}
