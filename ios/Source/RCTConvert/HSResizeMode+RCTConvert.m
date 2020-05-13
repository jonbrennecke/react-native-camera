#import "HSReactNativeCamera-Swift-Umbrella.h"
#import <React/RCTConvert.h>

@implementation RCTConvert (HSResizeMode)

RCT_ENUM_CONVERTER(HSResizeMode, (@{
                     @"scaleAspectFill" : @(HSResizeModeScaleAspectFill),
                     @"scaleAspectWidth" : @(HSResizeModeScaleAspectWidth),
                     @"scaleAspectHeight" : @(HSResizeModeScaleAspectHeight),
                   }),
                   HSResizeModeScaleAspectFill, integerValue)

@end
