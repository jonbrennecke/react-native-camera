#pragma once

#import <Foundation/Foundation.h>
#import <React/RCTConvert.h>

#import "HSReactNativeCamera-Swift.h"

@interface RCTConvert (HSCameraResolutionPreset)
+ (HSCameraResolutionPreset)HSCameraResolutionPreset:(id)json;
@end
