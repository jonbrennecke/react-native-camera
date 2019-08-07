#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <React/RCTConvert.h>

@implementation RCTConvert (AVCaptureDevicePosition)

RCT_ENUM_CONVERTER(AVCaptureDevicePosition, (@{
                     @"front" : @(AVCaptureDevicePositionFront),
                     @"back" : @(AVCaptureDevicePositionBack),
                   }),
                   AVCaptureDevicePositionFront, integerValue)

@end
