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

RCT_CUSTOM_VIEW_PROPERTY(isDepthPreviewEnabled, BOOL, HSVideoCompositionView) {
  BOOL isDepthPreviewEnabled = [RCTConvert BOOL:json];
  view.isDepthPreviewEnabled = isDepthPreviewEnabled;
}

RCT_CUSTOM_VIEW_PROPERTY(isPortraitModeEnabled, BOOL, HSVideoCompositionView) {
  BOOL isPortraitModeEnabled = [RCTConvert BOOL:json];
  view.isPortraitModeEnabled = isPortraitModeEnabled;
}

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

@end
