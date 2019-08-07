#pragma

#import "HSReactNativeCamera-Swift.h"
#import <React/RCTConvert.h>

@implementation RCTConvert (HSEffectPreviewMode)

RCT_ENUM_CONVERTER(HSEffectPreviewMode, (@{
                     @"normal" : @(HSEffectPreviewModeNormal),
                     @"portraitMode" : @(HSEffectPreviewModePortraitMode),
                     @"depth" : @(HSEffectPreviewModeDepth),
                   }),
                   HSEffectPreviewModePortraitMode, integerValue)

@end
