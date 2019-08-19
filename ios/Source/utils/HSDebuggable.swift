import Foundation

protocol HSDebuggable {
  var isDebugLogEnabled: Bool { get set }
  func debugPrefix(describing selector: Selector) -> String
}

extension HSDebuggable {
  func debugPrefix(describing selector: Selector) -> String {
    return "[\(String(describing: Self.self)) \(String(describing: selector))]:"
  }
}
