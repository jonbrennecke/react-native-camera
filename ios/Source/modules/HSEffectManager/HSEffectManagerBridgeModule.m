#import <React/RCTUtils.h>

#import "HSEffectManagerBridgeModule.h"
#import "HSReactNativeCamera-Swift.h"

@implementation HSEffectManagerBridgeModule

RCT_EXPORT_MODULE(HSEffectManager)

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    if (@available(iOS 11.1, *)) {
      HSCameraManager.sharedInstance.depthDelegate = self;
    } else {
      // Fallback on earlier versions
    }
  }
  return self;
}

RCT_EXPORT_METHOD(startEffects) { NSLog(@"starting effects"); }

- (void)cameraManagerDidOutputDepthData:(AVDepthData *)depthData
                              videoData:(CMSampleBufferRef *)videoData {
  [HSEffectManager.sharedInstance applyEffectWithDepthData:depthData
                                                 videoData:videoData];
}

@end
