#pragma once

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@protocol HSVideoCompositionExportManagerDelegate;

@class HSVideoCompositionExportManagerBridgeModule;
@interface HSVideoCompositionExportManagerBridgeModule
    : RCTEventEmitter <RCTBridgeModule, HSVideoCompositionExportManagerDelegate>

- (void)videoExportManagerDidDidUpdateProgress:(float)progress;
- (void)videoExportManagerDidFailWithError:(NSError *_Nonnull)error;
- (void)videoExportManagerDidFinishExporting:(NSURL *_Nonnull)url;

@end
