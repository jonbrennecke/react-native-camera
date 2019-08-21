#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTUIManager.h>
#import <React/RCTUtils.h>

#import "HSReactNativeCamera-Swift.h"
#import "HSVideoCompositionViewManager.h"

@implementation HSVideoCompositionViewManager

RCT_EXPORT_MODULE()

- (UIView *)view {
  HSVideoCompositionBridgeView *view =
      [[HSVideoCompositionBridgeView alloc] init];
  view.playbackDelegate = self;
  return view;
}

RCT_CUSTOM_VIEW_PROPERTY(assetID, NSString, HSVideoCompositionView) {
  NSString *assetID = [RCTConvert NSString:json];
  [view loadAssetByID:assetID];
}

RCT_EXPORT_VIEW_PROPERTY(previewMode, HSEffectPreviewMode)

RCT_EXPORT_VIEW_PROPERTY(resizeMode, HSResizeMode)

RCT_EXPORT_VIEW_PROPERTY(blurAperture, float)

RCT_EXPORT_VIEW_PROPERTY(isReadyToLoad, BOOL)

RCT_EXPORT_VIEW_PROPERTY(onPlaybackProgress, RCTDirectEventBlock)

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

- (void)videoCompositionView:(HSVideoCompositionView *_Nonnull)view
           didUpdateProgress:(CFTimeInterval)progress {
  if (![view isKindOfClass:[HSVideoCompositionBridgeView class]]) {
    return;
  }
  HSVideoCompositionBridgeView *bridgeView =
      (HSVideoCompositionBridgeView *)view;
  if (bridgeView.onPlaybackProgress) {
    bridgeView.onPlaybackProgress(@{ @"progress" : @(progress) });
  }
}

@end
