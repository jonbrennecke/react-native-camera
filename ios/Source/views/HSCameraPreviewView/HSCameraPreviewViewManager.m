#import <AVFoundation/AVFoundation.h>
#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTUIManager.h>

#import "HSCameraPreviewViewManager.h"
#import "HSReactNativeCamera-Swift.h"

@implementation HSCameraPreviewViewManager

RCT_EXPORT_MODULE(HSCameraPreviewViewManager)

RCT_EXPORT_METHOD(focusOnPoint
                  : (nonnull NSNumber *)reactTag focusPoint
                  : (id)pointJson) {
  CGPoint point = [RCTConvert CGPoint:pointJson];
  HSCameraManager *cameraManager = HSCameraManager.sharedInstance;
  [cameraManager focusOnPoint:point];
}

- (UIView *)view {
  HSCameraPreviewView *previewView = [[HSCameraPreviewView alloc] init];
  return (UIView *)previewView;
}

@end
