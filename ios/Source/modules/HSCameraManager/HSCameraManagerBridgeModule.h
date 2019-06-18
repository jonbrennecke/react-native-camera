#pragma once

#import "HSReactNativeCamera-Swift.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface HSCameraManagerBridgeModule
    : RCTEventEmitter <RCTBridgeModule, HSCameraManagerDelegate>
- (void)cameraManagerDidBeginFileOutputToFileURL:(NSURL *)fileURL;
- (void)cameraManagerDidFinishFileOutputToFileURL:(NSURL *)fileURL
                                            asset:(PHObjectPlaceholder *)asset
                                            error:(NSError *)error;
- (void)cameraManagerDidReceiveCameraDataOutputWithVideoData:
    (CMSampleBufferRef)videoData;
@end
