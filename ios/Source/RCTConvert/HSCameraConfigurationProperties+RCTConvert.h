#pragma once

#import <Foundation/Foundation.h>
#import <React/RCTConvert.h>

#import "HSReactNativeCamera-Swift.h"

@interface RCTConvert (HSCameraConfigurationProperties)
+ (HSCameraConfigurationProperties*)HSCameraConfigurationProperties:(id)json;
@end
