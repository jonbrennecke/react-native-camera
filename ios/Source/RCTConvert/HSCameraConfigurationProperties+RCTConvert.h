#pragma once

#import <Foundation/Foundation.h>
#import <React/RCTConvert.h>

@class HSCameraConfigurationProperties;

@interface RCTConvert (HSCameraConfigurationProperties)
+ (HSCameraConfigurationProperties *)HSCameraConfigurationProperties:(id)json;
@end
