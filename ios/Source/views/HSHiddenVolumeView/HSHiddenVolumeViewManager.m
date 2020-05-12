#import "HSHiddenVolumeViewManager.h"
#import "HSReactNativeCamera-Swift.h"

@implementation HSHiddenVolumeViewManager

RCT_EXPORT_MODULE(HSHiddenVolumeViewManager)

- (UIView *)view {
  HSHiddenVolumeView *volumeView = [[HSHiddenVolumeView alloc] init];
  return (UIView *)volumeView;
}

@end
