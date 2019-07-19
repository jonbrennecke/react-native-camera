import AVFoundation

//class HSCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol {
//  var timeRange: CMTimeRange
//
//  var enablePostProcessing: Bool = true
//
//  var containsTweening: Bool = false
//
//  var requiredSourceTrackIDs: [NSValue]?
//
//  var passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
//
//  init(timeRange: CMTimeRange, trackIDs: [CMPersistentTrackID]) {
//    self.timeRange = timeRange
//    self.requiredSourceTrackIDs = trackIDs.map { NSNumber(value: $0) }
//  }
//}

class HSCompositionInstruction: AVMutableVideoCompositionInstruction {
  private var trackIDs: [CMPersistentTrackID]
  
  override var requiredSourceTrackIDs: [NSValue] {
    get {
      return trackIDs.map { NSNumber(value: $0) }
    }
  }
  
  override var passthroughTrackID: CMPersistentTrackID {
    get {
      return trackIDs.first!
    }
  }
  
  init(timeRange: CMTimeRange, trackIDs: [CMPersistentTrackID]) {
    self.trackIDs = trackIDs
    super.init()
    self.timeRange = timeRange
    self.enablePostProcessing = true
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
