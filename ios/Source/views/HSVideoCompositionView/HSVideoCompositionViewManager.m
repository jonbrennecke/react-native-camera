#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTUIManager.h>
#import <React/RCTUtils.h>

#import "HSReactNativeCamera-Swift.h"
#import "HSVideoCompositionViewManager.h"

@implementation HSVideoCompositionViewManager

RCT_EXPORT_MODULE()

- (UIView *)view {
  HSVideoCompositionView *view = [[HSVideoCompositionView alloc] init];
  return view;
}

RCT_CUSTOM_VIEW_PROPERTY(assetID, NSString, HSVideoCompositionView) {
  NSString *assetID = [RCTConvert NSString:json];
  [view loadAssetByID:assetID];
}

RCT_EXPORT_VIEW_PROPERTY(previewMode, HSEffectPreviewMode)

RCT_EXPORT_METHOD(play : (nonnull NSNumber *)reactTag) {
  [self.bridge.uiManager addUIBlock:^(
                             RCTUIManager *uiManager,
                             NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    HSVideoCompositionView *view =
        (HSVideoCompositionView *)viewRegistry[reactTag];
    if (!view || ![view isKindOfClass:[HSVideoCompositionView class]]) {
      RCTLogError(@"Cannot find HSVideoCompositionView with tag #%@", reactTag);
      return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      [view play];
    });
  }];
}

RCT_EXPORT_METHOD(pause : (nonnull NSNumber *)reactTag) {
  [self.bridge.uiManager addUIBlock:^(
                             RCTUIManager *uiManager,
                             NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    HSVideoCompositionView *view =
        (HSVideoCompositionView *)viewRegistry[reactTag];
    if (!view || ![view isKindOfClass:[HSVideoCompositionView class]]) {
      RCTLogError(@"Cannot find HSVideoCompositionView with tag #%@", reactTag);
      return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      [view pause];
    });
  }];
}

RCT_EXPORT_METHOD(seekToTime
                  : (nonnull NSNumber *)reactTag withSeconds
                  : (nonnull NSNumber *)seconds) {
  [self.bridge.uiManager addUIBlock:^(
                             RCTUIManager *uiManager,
                             NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    HSVideoCompositionView *view =
        (HSVideoCompositionView *)viewRegistry[reactTag];
    if (!view || ![view isKindOfClass:[HSVideoCompositionView class]]) {
      RCTLogError(@"Cannot find HSVideoCompositionView with tag #%@", reactTag);
      return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      CMTime time = CMTimeMakeWithSeconds([seconds floatValue], 600);
      [view seekTo:time];
    });
  }];
}

RCT_EXPORT_METHOD(seekToProgress
                  : (nonnull NSNumber *)reactTag withProgress
                  : (nonnull NSNumber *)progress) {
  [self.bridge.uiManager addUIBlock:^(
                             RCTUIManager *uiManager,
                             NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    HSVideoCompositionView *view =
        (HSVideoCompositionView *)viewRegistry[reactTag];
    if (!view || ![view isKindOfClass:[HSVideoCompositionView class]]) {
      RCTLogError(@"Cannot find HSVideoCompositionView with tag #%@", reactTag);
      return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      [view seekToProgress:[progress doubleValue]];
    });
  }];
}

@end
