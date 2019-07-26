import Foundation

@objc
protocol NSDictionaryConvertible {
  @objc func asDictionary() -> NSDictionary
}

extension Array where Element: NSDictionaryConvertible {
  func asDictionaries() -> Array<NSDictionary> {
    return map { $0.asDictionary() }
  }
}
