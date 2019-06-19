#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>

#import "HSCameraEffectViewManager.h"
#import "HSReactNativeCamera-Swift.h"

@implementation HSCameraEffectViewManager

RCT_EXPORT_MODULE(HSCameraEffectViewManager)

- (UIView *)view {
  HSCameraEffectView *previewView = [[HSCameraEffectView alloc] init];
  return (UIView *)previewView;
}

@end
