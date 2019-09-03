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

RCT_EXPORT_METHOD(hasCameraPermissions : (RCTResponseSenderBlock)callback) {
  BOOL hasPermissons = [HSCameraManager hasCameraPermissions];
  callback(@[ [NSNull null], @(hasPermissons) ]);
}

RCT_EXPORT_METHOD(getSupportedISORange : (RCTResponseSenderBlock)callback) {
  HSCameraManager *cameraManager = HSCameraManager.sharedInstance;
  NSDictionary *range = [cameraManager.supportedISORange asDictionary];
  callback(@[ [NSNull null], range ]);
}

RCT_EXPORT_METHOD(setISO
                  : (nonnull NSNumber *)iso callback
                  : (RCTResponseSenderBlock)callback) {
  HSCameraManager *cameraManager = HSCameraManager.sharedInstance;
  [cameraManager setISO:[iso floatValue]
      withCompletionHandler:^{
        callback(@[ [NSNull null], [NSNull null] ]);
      }];
}

RCT_EXPORT_METHOD(getSupportedExposureRange
                  : (RCTResponseSenderBlock)callback) {
  HSCameraManager *cameraManager = HSCameraManager.sharedInstance;
  NSDictionary *range = [cameraManager.supportedExposureRange asDictionary];
  callback(@[ [NSNull null], range ]);
}

RCT_EXPORT_METHOD(setExposure
                  : (nonnull NSNumber *)exposure callback
                  : (RCTResponseSenderBlock)callback) {
  HSCameraManager *cameraManager = HSCameraManager.sharedInstance;
  [cameraManager setExposure:[exposure floatValue]
       withCompletionHandler:^{
         callback(@[ [NSNull null], [NSNull null] ]);
       }];
}

RCT_EXPORT_METHOD(getSupportedFormats : (RCTResponseSenderBlock)callback) {
  HSCameraManager *cameraManager = HSCameraManager.sharedInstance;
  NSMutableArray<id> *formats = [[NSMutableArray alloc]
      initWithCapacity:cameraManager.supportedFormats.count];
  for (HSCameraFormat *format in cameraManager.supportedFormats) {
    [formats addObject:[format asDictionary]];
  }
  callback(@[ [NSNull null], formats ]);
}

RCT_EXPORT_METHOD(getFormat : (RCTResponseSenderBlock)callback) {
  HSCameraFormat *format = HSCameraManager.sharedInstance.format;
  if (!format) {
    NSString *description = @"Failed to get camera format";
    NSDictionary<NSString *, id> *error = RCTMakeError(description, @{}, nil);
    callback(@[ error, [NSNull null] ]);
    return;
  }
  callback(@[ [NSNull null], [format toNSDictionary] ]);
}

RCT_EXPORT_METHOD(getDepthFormat : (RCTResponseSenderBlock)callback) {
  HSCameraFormat *depthFormat = HSCameraManager.sharedInstance.depthFormat;
  if (!depthFormat) {
    NSString *description = @"Failed to get camera depth format";
    NSDictionary<NSString *, id> *error = RCTMakeError(description, @{}, nil);
    callback(@[ error, [NSNull null] ]);
    return;
  }
  callback(@[ [NSNull null], [depthFormat toNSDictionary] ]);
}

RCT_EXPORT_METHOD(setFormat
                  : (NSDictionary *)formatJson depthFormat
                  : (NSDictionary *)depthFormatJson callback
                  : (RCTResponseSenderBlock)callback) {
  HSCameraFormat *format =
      (HSCameraFormat *)[HSCameraFormat fromDictionary:formatJson];
  HSCameraFormat *depthFormat =
      (HSCameraFormat *)[HSCameraFormat fromDictionary:depthFormatJson];
  if (!format || !depthFormat) {
    NSString *description = @"Failed to get parse input format values";
    NSDictionary<NSString *, id> *error = RCTMakeError(description, @{}, nil);
    callback(@[ error, [NSNull null] ]);
    return;
  }
  [HSCameraManager.sharedInstance setFormat:format
                            withDepthFormat:depthFormat
                          completionHandler:^{
                            callback(@[ [NSNull null], [NSNull null] ]);
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

RCT_EXPORT_METHOD(stopCameraCapture
                  : (BOOL)saveToCameraRoll metadata
                  : (NSDictionary *)metadata callback
                  : (RCTResponseSenderBlock)callback) {
  [HSCameraManager.sharedInstance
      stopCaptureAndSaveToCameraRoll:saveToCameraRoll
                      customMetadata:metadata
                   completionHandler:^(BOOL success, NSURL *_Nullable url) {
                     if (!success) {
                       NSString *description = @"Failed to stop camera capture";
                       NSDictionary<NSString *, id> *error =
                           RCTMakeError(description, @{}, nil);
                       callback(@[ error ]);
                       return;
                     }
                     id urlString = url ? [url absoluteString] : [NSNull null];
                     callback(@[ [NSNull null], @{@"url" : urlString} ]);
                   }];
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
  // TODO: this should be an HSMediaAsset
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

- (void)cameraManagerDidDetectFaces:(NSArray<AVMetadataFaceObject *> *)faces {
}

@end
