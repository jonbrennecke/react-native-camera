#pragma once

#import "HSReactNativeCamera-Swift.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@class HSCameraManagerBridgeModule;
@interface HSCameraManagerBridgeModule : RCTEventEmitter <RCTBridgeModule>
@end
