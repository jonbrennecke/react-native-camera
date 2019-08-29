#import "HSVideoCompositionImageViewManager.h"

@implementation HSVideoCompositionImageViewManager

RCT_EXPORT_MODULE(HSVideoCompositionImageViewManager)

- (UIView *)view {
    HSVideoCompositionImageView *imageView = [[HSVideoCompositionImageView alloc] init];
    return (UIView *)imageView;
}

RCT_EXPORT_VIEW_PROPERTY(previewMode, HSEffectPreviewMode)

RCT_EXPORT_VIEW_PROPERTY(resizeMode, HSResizeMode)

RCT_EXPORT_VIEW_PROPERTY(blurAperture, float)

RCT_CUSTOM_VIEW_PROPERTY(resourceNameWithExt, NSString*, HSVideoCompositionImageView) {
  NSString* resourceNameWithExt = [RCTConvert NSString:json];
  if (!resourceNameWithExt) {
    return;
  }
  [view generateImageByResourceName:resourceNameWithExt extension:@"" completionHandler:nil];
}

@end
