import Foundation

internal final class WeakReference<T> where T: AnyObject {
  internal weak var value: T?

  init(value: T?) {
    self.value = value
  }
}
