import Foundation

internal func normalize<T: FloatingPoint>(_ x: T, min: T, max: T) -> T {
  return (x - min) / (max - min)
}

internal func clamp<T: FloatingPoint>(_ x: T, min xMin: T, max xMax: T) -> T {
  if x.isNaN {
    return xMin
  }
  return max(min(x, xMax), xMin)
}

internal func clamp<T: SignedInteger>(_ x: T, min xMin: T, max xMax: T) -> T {
  return max(min(x, xMax), xMin)
}

internal func symmetricDerivative(_ x: Int, _ h: Int, _ f: (Int) -> Float32) -> Float32 {
  return (f(x + h) - f(x - h)) / 2 * Float32(h)
}

internal func symmetricSecondDerivative(_ x: Int, _ h: Int, _ f: (Int) -> Float32) -> Float32 {
  return (f(x + h) - 2 * f(x) + f(x - h)) / Float32(h * h)
}
