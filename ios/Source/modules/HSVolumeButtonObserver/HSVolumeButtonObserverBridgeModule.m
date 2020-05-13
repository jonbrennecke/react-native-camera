#import "HSVolumeButtonObserverBridgeModule.h"
#import "HSReactNativeCamera-Swift-Umbrella.h"
#import <Foundation/Foundation.h>
#import <React/RCTConvert.h>
#import <React/RCTUtils.h>

@implementation HSVolumeButtonObserverBridgeModule {
  bool hasListeners;
  HSVolumeButtonObserver *volumeButtonObserver;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    volumeButtonObserver = [[HSVolumeButtonObserver alloc] init];
  }
  return self;
}

- (void)startObserving {
  hasListeners = YES;
  [volumeButtonObserver startObservingVolumeButtonWith:self];
}

- (void)stopObserving {
  hasListeners = NO;
  [volumeButtonObserver stopObservingVolumeButton];
}

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

- (NSArray<NSString *> *)supportedEvents {
  return @[
    @"volumeButtonObserverDidChangeVolume",
    @"volumeButtonObserverDidEncounterError",
  ];
}

RCT_EXPORT_MODULE(HSVolumeButtonObserver)

#pragma MARK - HSVolumeButtonObserverDelegate methods

- (void)volumeButtonObserverDidChangeVolume:(float)volume {
  if (!hasListeners) {
    return;
  }
  id body = @{ @"volume" : @(volume) };
  [self sendEventWithName:@"volumeButtonObserverDidChangeVolume" body:body];
}

- (void)volumeButtonObserverDidEncounterError:(NSError *_Nonnull)error {
  if (!hasListeners) {
    return;
  }
  id jsError = RCTJSErrorFromNSError(error);
  [self sendEventWithName:@"volumeButtonObserverDidEncounterError"
                     body:jsError];
}

@end
