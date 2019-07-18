#import <React/RCTUtils.h>

#import "HSEffectCompositorBridgeModule.h"
#import "HSReactNativeCamera-Swift.h"

@implementation HSEffectCompositorBridgeModule

RCT_EXPORT_MODULE(HSEffectCompositor)

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

- (instancetype)init {
  self = [super init];
  return self;
}

RCT_EXPORT_METHOD(createComposition
                  : (NSString *)assetID callback
                  : (RCTResponseSenderBlock)callback) {
  [HSEffectComposition compositionWithAssetID:assetID];
  callback(@[ [NSNull null], @(YES) ]);
}

@end
