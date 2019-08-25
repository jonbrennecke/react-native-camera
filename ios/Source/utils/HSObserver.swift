import Foundation

class HSObserver {
  private let uuid = UUID()

  internal var isPaused = false
}

extension HSObserver: Equatable {
  static func == (lhs: HSObserver, rhs: HSObserver) -> Bool {
    return lhs.uuid == rhs.uuid
  }
}
