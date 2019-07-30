import Foundation

@objc
public final class HSMinMaxInterval: NSObject {
  public let min: Float
  public let max: Float

  public static let zero = HSMinMaxInterval(min: .zero, max: .zero)

  @objc
  public init(min: Float, max: Float) {
    self.min = min
    self.max = max
  }
}

extension HSMinMaxInterval: NSDictionaryConvertible {
  @objc
  public func asDictionary() -> NSDictionary {
    return ["min": min, "max": max] as NSDictionary
  }
}
