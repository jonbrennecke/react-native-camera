#import "HSVideoCompositionExportManagerBridgeModule.h"
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <React/RCTConvert.h>
#import <React/RCTUtils.h>

@implementation HSVideoCompositionExportManagerBridgeModule {
  bool hasListeners;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    HSVideoCompositionExportManager.sharedInstance.delegate = self;
  }
  return self;
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
    @"videoExportManagerDidUpdateProgress", @"videoExportManagerDidFinish",
    @"videoExportManagerDidFail"
  ];
}

RCT_EXPORT_MODULE(HSVideoCompositionExportManager)

RCT_EXPORT_METHOD(export
                  : (NSString *)assetID config
                  : (nullable NSDictionary *)config callback
                  : (RCTResponseSenderBlock)callback) {
  [self
      fetchAVAssetWithAssetID:assetID
            completionHandler:^(AVAsset *asset) {
              if (!asset) {
                NSString *description = [NSString
                    stringWithFormat:@"Failed to load asset with assetID = %@",
                                     assetID];
                NSDictionary<NSString *, id> *error =
                    RCTMakeError(description, @{}, nil);
                callback(@[ error, [NSNull null] ]);
              }
              [HSVideoComposition
                  compositionByLoadingAsset:asset
                      withCompletionHandler:^(
                          HSVideoComposition *_Nullable composition) {
                        if (!composition) {
                          NSString *description = @"Failed to load composition";
                          NSDictionary<NSString *, id> *error =
                              RCTMakeError(description, @{}, nil);
                          callback(@[ error, [NSNull null] ]);
                          return;
                        }

                        if (config) {
                          for (NSString *key in [config allKeys]) {
                            id value = [config valueForKey:key];
                            [composition setMetadataValue:value forKey:key];
                          }
                        }

                        [HSVideoCompositionExportManager.sharedInstance
                            exportComposition:composition];
                      }];
            }];
}

- (void)fetchAVAssetWithAssetID:(NSString *)assetID
              completionHandler:(void (^)(AVAsset *))completionHandler {
  PHFetchResult<PHAsset *> *fetchResult =
      [PHAsset fetchAssetsWithLocalIdentifiers:@[ assetID ] options:nil];
  PHAsset *asset = fetchResult.firstObject;
  if (!asset) {
    completionHandler(nil);
    return;
  }
  [PHImageManager.defaultManager
      requestAVAssetForVideo:asset
                     options:nil
               resultHandler:^(AVAsset *_Nullable asset,
                               AVAudioMix *_Nullable _1,
                               NSDictionary *_Nullable _2) {
                 completionHandler(asset);
               }];
}

#pragma MARK - HSVideoCompositionExportManagerDelegate methods

- (void)videoExportManagerDidDidUpdateProgress:(float)progress {
  if (!hasListeners) {
    return;
  }
  id body = @{ @"progress" : @(progress) };
  [self sendEventWithName:@"videoExportManagerDidUpdateProgress" body:body];
}

- (void)videoExportManagerDidFailWithError:(NSError *_Nonnull)error {
  if (!hasListeners) {
    return;
  }
  id body = RCTJSErrorFromNSError(error);
  [self sendEventWithName:@"videoExportManagerDidFail" body:body];
}

- (void)videoExportManagerDidFinishExporting:(NSURL *_Nonnull)url {
  if (!hasListeners) {
    return;
  }
  id body = @{@"url" : [url absoluteString]};
  [self sendEventWithName:@"videoExportManagerDidFinish" body:body];
}

@end
