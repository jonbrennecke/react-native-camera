import AVFoundation
import HSCameraUtils
import UIKit

class HSVideoPreviewView: UIView {
  private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
    let layer = AVCaptureVideoPreviewLayer(session: HSCameraManager.shared.captureSession)
    return layer
  }()

  public var resizeMode: HSResizeMode = .scaleAspectWidth {
    didSet {
      previewLayer.videoGravity = resizeMode.videoGravity
    }
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    layer.backgroundColor = UIColor.black.cgColor
    layer.sublayers = nil
    layer.addSublayer(previewLayer)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let resolution = HSCameraManager.shared.videoResolution ?? Size<Int>(width: 480, height: 640)
    let aspectRatio = CGSize(width: resolution.width, height: resolution.height)
    let centeredRect = AVMakeRect(aspectRatio: aspectRatio, insideRect: bounds)
    let rectAtOrigin = CGRect(origin: .zero, size: centeredRect.size)
    previewLayer.frame = rectAtOrigin
  }
}
