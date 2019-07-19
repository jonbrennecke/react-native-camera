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
  view.assetID = assetID;
}

@end
