import AVFoundation

@objc
public enum HSResizeMode: Int {
  case scaleAspectWidth
  case scaleAspectHeight
  case scaleAspectFill
    
  public var videoGravity: AVLayerVideoGravity {
    switch self {
    case .scaleAspectFill:
      return .resizeAspectFill
    case .scaleAspectWidth:
      return .resizeAspect
    case .scaleAspectHeight:
      return .resizeAspect
    }
  }
}
