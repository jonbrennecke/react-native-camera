#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>

#import "HSCameraEffectViewManager.h"
#import "HSReactNativeCamera-Swift.h"

@implementation HSCameraEffectViewManager

RCT_EXPORT_MODULE(HSCameraEffectViewManager)

RCT_EXPORT_VIEW_PROPERTY(isDepthPreviewEnabled, BOOL)

- (UIView *)view {
  HSCameraEffectView *previewView = [[HSCameraEffectView alloc] init];
  return (UIView *)previewView;
}

@end
