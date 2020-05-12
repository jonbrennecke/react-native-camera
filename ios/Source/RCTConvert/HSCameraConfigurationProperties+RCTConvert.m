#import "HSCameraConfigurationProperties+RCTConvert.h"
#import "HSCameraResolutionPreset+RCTConvert.h"

#import "HSReactNativeCamera-Swift.h"

@implementation RCTConvert (HSCameraConfigurationProperties)

RCT_ENUM_CONVERTER(HSCameraResolutionPreset, (@{
                     @"hd720p" : @(HSCameraResolutionPresetHD720p),
                     @"hd1080p" : @(HSCameraResolutionPresetHD1080p),
                     @"hd4K" : @(HSCameraResolutionPresetHD4K),
                     @"vga" : @(HSCameraResolutionPresetVGA),
                   }),
                   HSCameraResolutionPresetHD720p, integerValue)

+ (HSCameraConfigurationProperties *)HSCameraConfigurationProperties:(id)json {
  NSDictionary *dict = [RCTConvert NSDictionary:json];
  if (!dict) {
    return NULL;
  }
  HSCameraResolutionPreset resolutionPreset = [RCTConvert
      HSCameraResolutionPreset:[dict valueForKey:@"resolutionPreset"]];
  BOOL depthEnabled = [RCTConvert BOOL:[dict valueForKey:@"depthEnabled"]];
  return [[HSCameraConfigurationProperties alloc]
      initWithResolutionPreset:resolutionPreset
                  depthEnabled:depthEnabled];
}

@end
