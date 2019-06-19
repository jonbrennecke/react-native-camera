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
    HSCameraManager.sharedInstance.depthDelegate = self;
  }
  return self;
}

RCT_EXPORT_METHOD(startEffects) { NSLog(@"starting effects"); }

- (void)cameraManagerDidOutputDepthData:(AVDepthData *)depthData {
  [HSEffectManager.sharedInstance applyEffectWithDepthData:depthData];
}

@end
