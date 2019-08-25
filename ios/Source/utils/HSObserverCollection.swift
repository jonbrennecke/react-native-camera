import Foundation

class HSObserverCollection<T: HSObserver> {
  private var observers = Array<WeakReference<T>>()

  public var count: Int {
    return observers.count
  }

  public func removeObserver(_ observer: T) {
    observers.removeAll { ref in
      guard let value = ref.value else { return false }
      return value == observer
    }
  }

  public func addObserver(_ observer: T) {
    observers.append(WeakReference(value: observer))
  }

  public func forEach(_ body: (T) throws -> Void) rethrows {
    try observers.forEach { ref in
      guard let value = ref.value else {
        return
      }
      try body(value)
    }
  }
}
