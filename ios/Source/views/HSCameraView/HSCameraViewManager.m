#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTUIManager.h>

#import "HSCameraViewManager.h"
#import "HSReactNativeCamera-Swift.h"

@implementation HSCameraViewManager

RCT_EXPORT_MODULE(HSCameraViewManager)

- (UIView *)view {
  HSCameraView *previewView = [[HSCameraView alloc] init];
  return (UIView *)previewView;
}

RCT_EXPORT_METHOD(focusOnPoint
                  : (nonnull NSNumber *)reactTag point
                  : (CGPoint)point) {
  [self.bridge.uiManager
      addUIBlock:^(RCTUIManager *uiManager,
                   NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        HSCameraView *view = (HSCameraView *)viewRegistry[reactTag];
        if (!view || ![view isKindOfClass:[HSCameraView class]]) {
          RCTLogError(@"Cannot find HSCameraView with tag #%@", reactTag);
          return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
          [view focusOnPoint:point];
        });
      }];
}

@end
