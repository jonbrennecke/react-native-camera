#pragma once

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@protocol HSVolumeButtonObserverDelegate;
@class HSVolumeButtonObserver;

@class HSVolumeButtonObserverBridgeModule;
@interface HSVolumeButtonObserverBridgeModule
    : RCTEventEmitter <RCTBridgeModule, HSVolumeButtonObserverDelegate>
@property(nonatomic, copy) HSVolumeButtonObserver *volumeButtonObserver;
@end
