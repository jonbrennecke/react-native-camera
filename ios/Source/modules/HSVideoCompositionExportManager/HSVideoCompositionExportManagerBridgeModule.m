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
  return @[ @"videoExportManagerDidUpdateProgress" ];
}

RCT_EXPORT_MODULE(HSVideoCompositionExportManager)

RCT_EXPORT_METHOD(export
                  : (NSString *)assetID callback
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
  id body = @{ @"progess" : @(progress) };
  [self sendEventWithName:@"videoExportManagerDidUpdateProgress" body:body];
}

- (void)videoExportManagerDidFailWithError:(NSError *_Nonnull)error {
}

- (void)videoExportManagerDidFinishExporting:(NSURL *_Nonnull)url {
}

@end
