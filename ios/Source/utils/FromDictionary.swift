import Foundation

public protocol FromDictionary {
  static func from(dictionary: [String: Any]) -> Self?
}

@objc
public protocol FromNSDictionary {
  @objc static func from(dictionary: NSDictionary) -> FromNSDictionary?
}

extension FromNSDictionary where Self: FromDictionary {
  public static func from(dictionary: NSDictionary) -> FromDictionary? {
    guard let swiftDict = dictionary as? [String: Any] else {
      return nil
    }
    return Self.from(dictionary: swiftDict)
  }
}

extension Array where Element: FromDictionary {
  public static func from(arrayOfDictionaries: [[String: Any]]) -> [Element]? {
    var newArray = [Element]()
    for dictionary in arrayOfDictionaries {
      guard let element = Element.from(dictionary: dictionary) else {
        return nil
      }
      newArray.append(element)
    }
    return newArray
  }
}
