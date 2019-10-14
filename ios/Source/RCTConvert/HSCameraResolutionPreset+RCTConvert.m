#import "HSCameraResolutionPreset+RCTConvert.h"

@implementation RCTConvert (HSCameraResolutionPreset)

RCT_ENUM_CONVERTER(HSCameraResolutionPreset, (@{
                     @"hd720p" : @(HSCameraResolutionPresetHD720p),
                     @"hd1080p" : @(HSCameraResolutionPresetHD1080p),
                     @"hd4K" : @(HSCameraResolutionPresetHD4K),
                     @"vga" : @(HSCameraResolutionPresetVGA),
                   }),
                   HSCameraResolutionPresetHD720p, integerValue)

@end
