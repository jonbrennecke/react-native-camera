#import "HSReactNativeCamera-Swift.h"
#import <React/RCTConvert.h>

@implementation RCTConvert (HSVideoPlaybackState)

RCT_ENUM_CONVERTER(HSVideoPlaybackState, (@{
                     @"playing" : @(HSVideoPlaybackStatePlaying),
                     @"paused" : @(HSVideoPlaybackStatePaused),
                     @"waiting" : @(HSVideoPlaybackStateWaiting),
                   }),
                   HSVideoPlaybackStateWaiting, integerValue)

@end
