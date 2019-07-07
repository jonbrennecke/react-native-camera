import Foundation

internal func normalize<T: FloatingPoint>(_ x: T, min: T, max: T) -> T {
  let clampedX = clamp(x, min: min, max: max)
  return (clampedX - min) / (max - min)
}

internal func clamp<T: FloatingPoint>(_ x: T, min xMin: T, max xMax: T) -> T {
  if x.isNaN {
    return xMin
  }
  if x == T.infinity {
    return xMax
  }
  if x == -T.infinity {
    return xMin
  }
  return max(min(x, xMax), xMin)
}

internal func clamp<T: SignedInteger>(_ x: T, min xMin: T, max xMax: T) -> T {
  return max(min(x, xMax), xMin)
}
