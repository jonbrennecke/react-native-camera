#pragma once

#import <React/RCTViewManager.h>

@protocol HSVideoCompositionViewPlaybackDelegate;

@class HSVideoCompositionViewManager;
@interface HSVideoCompositionViewManager
    : RCTViewManager <HSVideoCompositionViewPlaybackDelegate>
@end
