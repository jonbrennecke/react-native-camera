extension HSMinMaxInterval: FromDictionary {
  public static func from(dictionary: [String: Any]) -> HSMinMaxInterval? {
    guard
      let minValue = dictionary["min"] as? Float,
      let maxValue = dictionary["max"] as? Float
    else {
      return nil
    }
    return HSMinMaxInterval(min: minValue, max: maxValue)
  }
}
