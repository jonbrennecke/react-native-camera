import Foundation

public func scaleForResizing(_ originalSize: CGSize, to size: CGSize, resizeMode: HSResizeMode) -> CGFloat {
  let aspectRatio = originalSize.width / originalSize.height
  let scaleHeight = (size.height * aspectRatio) / size.width
  let scaleWidth = size.width / originalSize.width
  switch resizeMode {
  case .scaleAspectFill:
    return (originalSize.height * scaleWidth) < size.height
      ? scaleHeight
      : scaleWidth
  case .scaleAspectWidth:
    return scaleWidth
  case .scaleAspectHeight:
    return scaleHeight
  }
}
