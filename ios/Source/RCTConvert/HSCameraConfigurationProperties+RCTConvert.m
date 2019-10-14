#import "HSCameraConfigurationProperties+RCTConvert.h"
#import "HSCameraResolutionPreset+RCTConvert.h"

@implementation RCTConvert (HSCameraConfigurationProperties)

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
