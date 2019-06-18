#import <Photos/Photos.h>
#import <React/RCTUtils.h>

#import "HSCameraManagerBridgeModule.h"
#import "HSReactNativeCamera-Swift.h"

@implementation HSCameraManagerBridgeModule {
  bool hasListeners;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    HSCameraManager.sharedInstance.delegate = self;
  }
  return self;
}

RCT_EXPORT_MODULE(HSCameraManager)

RCT_EXPORT_METHOD(requestCameraPermissions : (RCTResponseSenderBlock)callback) {
    [HSCameraManager requestCameraPermissions:^(BOOL success) {
        callback(@[ [NSNull null], @(success) ]);
    }];
}

RCT_EXPORT_METHOD(startCameraPreview) {
  HSCameraManager *cameraManager = HSCameraManager.sharedInstance;
  [cameraManager setupCameraCaptureSession];
  [cameraManager startPreview];
}

RCT_EXPORT_METHOD(stopCameraPreview) {
  HSCameraManager *cameraManager = HSCameraManager.sharedInstance;
  [cameraManager stopPreview];
}

RCT_EXPORT_METHOD(startCameraCapture : (RCTResponseSenderBlock)callback) {
  [HSCameraManager.sharedInstance
      startCaptureWithCompletionHandler:^(NSError *error, BOOL success) {
        if (error != nil) {
          callback(@[ error, @(NO) ]);
          return;
        }
        callback(@[ [NSNull null], @(YES) ]);
      }];
}

RCT_EXPORT_METHOD(stopCameraCapture) {
  [HSCameraManager.sharedInstance stopCapture];
}

RCT_EXPORT_METHOD(switchToOppositeCamera) {
  [HSCameraManager.sharedInstance switchToOppositeCamera];
}

- (void)startObserving {
  hasListeners = YES;
}

- (void)stopObserving {
  hasListeners = NO;
}

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

- (NSArray<NSString *> *)supportedEvents {
  return @[
    @"cameraManagerDidFinishFileOutput",
    @"cameraManagerDidFinishFileOutputWithError"
  ];
}

#pragma mark - CameraManagerDelegate

- (void)cameraManagerDidBeginFileOutputToFileURL:(NSURL *)fileURL {
  // unimplemented
}

- (void)cameraManagerDidFinishFileOutputToFileURL:(NSURL *)fileURL
                                            asset:(PHObjectPlaceholder *)asset
                                            error:(NSError *)error {
  if (!hasListeners) {
    return;
  }
  if (error) {
    NSString *description = error.localizedDescription;
    NSDictionary<NSString *, id> *error = RCTMakeError(description, @{}, nil);
    [self sendEventWithName:@"cameraManagerDidFinishFileOutputWithError"
                       body:error];
    return;
  }
  if (!asset) {
    return;
  }
  AVURLAsset *avasset = [[AVURLAsset alloc] initWithURL:fileURL options:nil];
  CMTime duration = avasset.duration;
  NSDictionary *body = @{
    @"id" : asset.localIdentifier,
    @"duration" : @(CMTimeGetSeconds(duration))
  };
  [self sendEventWithName:@"cameraManagerDidFinishFileOutput" body:body];
}

- (void)cameraManagerDidReceiveCameraDataOutputWithVideoData:
    (CMSampleBufferRef)videoData {
  // unimplemented
}

@end
