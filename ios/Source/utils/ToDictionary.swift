import Foundation

public protocol ToDictionary {
  func toDictionary() -> Dictionary<String, Any>
}

@objc
public protocol ToNSDictionary {
  @objc func toNSDictionary() -> NSDictionary
}

// Does not work because swift won't let you put @objc decorator in a protocol extension
// extension ToNSDictionary where Self: ToDictionary {
//  public func toNSDictionary() -> NSDictionary {
//    return toDictionary() as NSDictionary
//  }
// }
