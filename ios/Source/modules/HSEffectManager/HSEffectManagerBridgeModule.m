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
  return self;
}

RCT_EXPORT_METHOD(start : (RCTResponseSenderBlock)callback) {
  if (@available(iOS 11.1, *)) {
    [[HSEffectManager sharedInstance] start];
    HSCameraManager.sharedInstance.depthDelegate = self;
    callback(@[ [NSNull null], @(YES) ]);
    return;
  }
  id error = RCTMakeError(
      @"Failed to start cammera effects; incompatible iOS version", nil, nil);
  callback(@[ error, @(NO) ]);
}

- (void)cameraManagerDidOutputDepthData:(AVDepthData *)depthData
                              videoData:(CMSampleBufferRef)videoData {
  NSError *error;
  [HSEffectManager.sharedInstance applyEffectWithDepthData:depthData
                                                 videoData:videoData
                                                     error:&error];
  if (error) {
    NSString *description =
        [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
    RCTMakeAndLogError(description, nil, nil);
  }
}

@end
