#import "HSCameraViewManager.h"
#import "HSReactNativeCamera-Swift.h"

@implementation HSCameraViewManager

RCT_EXPORT_MODULE(HSCameraViewManager)

- (UIView *)view {
  HSCameraView *previewView = [[HSCameraView alloc] init];
  return (UIView *)previewView;
}

@end
