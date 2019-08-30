#pragma once

#import "HSReactNativeCamera-Swift.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@class HSVolumeButtonObserverBridgeModule;
@interface HSVolumeButtonObserverBridgeModule
    : RCTEventEmitter <RCTBridgeModule, HSVolumeButtonObserverDelegate>
@property(nonatomic, copy) HSVolumeButtonObserver *volumeButtonObserver;
@end
