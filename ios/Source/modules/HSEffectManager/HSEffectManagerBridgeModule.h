#pragma once

#import "HSReactNativeCamera-Swift.h"
#import <React/RCTBridgeModule.h>

@class HSEffectManagerBridgeModule;
@interface HSEffectManagerBridgeModule
    : NSObject <RCTBridgeModule, HSCameraManagerDepthDataDelegate>
- (void)cameraManagerDidOutputDepthData:(AVDepthData *)depthData;
@end
