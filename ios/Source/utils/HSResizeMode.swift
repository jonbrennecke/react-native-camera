import AVFoundation
import UIKit

@objc
public enum HSResizeMode: Int {
  case scaleAspectWidth
  case scaleAspectHeight
  case scaleAspectFill

  public var videoGravity: AVLayerVideoGravity {
    switch self {
    case .scaleAspectFill:
      return .resizeAspectFill
    case .scaleAspectWidth, .scaleAspectHeight:
      return .resizeAspect
    }
  }

  public var contentMode: UIView.ContentMode {
    switch self {
    case .scaleAspectFill:
      return .scaleAspectFill
    case .scaleAspectWidth, .scaleAspectHeight:
      return .scaleAspectFit
    }
  }
}
