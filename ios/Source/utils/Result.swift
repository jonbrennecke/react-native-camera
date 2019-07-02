public enum Result<T, E> {
  case ok(T)
  case err(E)
}
