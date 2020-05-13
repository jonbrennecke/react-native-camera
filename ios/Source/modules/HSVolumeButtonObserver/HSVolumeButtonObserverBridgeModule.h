#pragma once

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@protocol HSVolumeButtonObserverDelegate;

@class HSVolumeButtonObserverBridgeModule;
@interface HSVolumeButtonObserverBridgeModule
    : RCTEventEmitter <RCTBridgeModule, HSVolumeButtonObserverDelegate>
@end
