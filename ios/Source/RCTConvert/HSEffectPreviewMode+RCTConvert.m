#pragma

#import "HSReactNativeCamera-Swift-Umbrella.h"
#import <React/RCTConvert.h>

@implementation RCTConvert (HSEffectPreviewMode)

RCT_ENUM_CONVERTER(HSEffectPreviewMode, (@{
                     @"normal" : @(HSEffectPreviewModeNormal),
                     @"portraitMode" : @(HSEffectPreviewModePortraitMode),
                     @"depth" : @(HSEffectPreviewModeDepth),
                   }),
                   HSEffectPreviewModeDepth, integerValue)

@end
