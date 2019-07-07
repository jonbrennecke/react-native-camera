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

- (NSString*)stringifyResult:(enum HSEffectManagerResult)result {
  switch (result) {
    case HSEffectManagerResultFailedToLoadModel:
      return @"Failed to load model";
    default:
      return @"Unknown error";
  }
}

RCT_EXPORT_METHOD(start : (RCTResponseSenderBlock)callback) {
  if (@available(iOS 11.1, *)) {
    [[HSEffectManager sharedInstance] start:^(enum HSEffectManagerResult result) {
      if (result != HSEffectManagerResultSuccess) {
        NSString* underlyingError = [self stringifyResult:result];
        NSString* errorMessage = [NSString stringWithFormat:@"Failed to start cammera effects; Error = %@", underlyingError];
        id error = RCTMakeError(errorMessage, nil, nil);
        callback(@[ error, @(NO) ]);
      } else {
        callback(@[ [NSNull null], @(YES) ]);
      }
    }];
    HSCameraManager.sharedInstance.depthDelegate = self;
    return;
  }
  id error = RCTMakeError(
      @"Failed to start cammera effects; incompatible iOS version", nil, nil);
  callback(@[ error, @(NO) ]);
}

- (void)cameraManagerDidOutputVideoSampleBuffer:(CMSampleBufferRef)videoSampleBuffer {
  HSEffectManager.sharedInstance.videoSampleBuffer = videoSampleBuffer;
}

- (void)cameraManagerDidOutputDepthData:(AVDepthData *)depthData {
  HSEffectManager.sharedInstance.depthData = depthData;
}

@end
