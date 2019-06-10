#import <Photos/PHAsset.h>
#import <React/RCTConvert.h>

#import "HSMediaLibraryBridgeModule.h"

@implementation HSMediaLibraryBridgeModule {
  bool hasListeners;
}

@synthesize mediaLibrary;

- (instancetype)init {
  self = [super init];
  if (self != nil) {
    mediaLibrary = [[HSMediaLibrary alloc] init];
    mediaLibrary.delegate = self;
  }
  return self;
}

#pragma mark - HSMediaLibraryDelegate

- (void)mediaLibraryManagerDidGenerateThumbnail:(UIImage *)thumbnail
                                  forTargetSize:(CGSize)size {
  if (!thumbnail || !hasListeners) {
    return;
  }
  [self sendEventWithName:@"mediaLibraryDidOutputThumbnail"
                     body:@{
                       @"size" : @(size),
                       @"image" : thumbnail
                     }];
}

- (void)mediaLibraryManagerDidUpdateVideos:(NSArray<PHAsset *> *)videoAssets {
  if (!hasListeners) {
    return;
  }
  NSMutableArray<NSDictionary *> *videos =
      [[NSMutableArray alloc] initWithCapacity:videoAssets.count];
  [videoAssets
      enumerateObjectsUsingBlock:^(PHAsset *_Nonnull asset, NSUInteger idx,
                                   BOOL *_Nonnull stop) {
        if (asset == nil) {
          return;
        }
        NSString *localIdentifier = asset.localIdentifier;
        NSTimeInterval duration = asset.duration;
        NSDictionary *video =
            @{ @"videoID" : localIdentifier,
               @"duration" : @(duration) };
        [videos insertObject:video atIndex:idx];
      }];
  [self sendEventWithName:@"mediaLibraryDidUpdateVideos"
                     body:@{@"videos" : videos}];
}

#pragma mark - React Native module

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
  return @[ @"mediaLibraryDidOutputThumbnail", @"mediaLibraryDidUpdateVideos" ];
}

RCT_EXPORT_MODULE(MediaLibrary)

RCT_EXPORT_METHOD(query
                  : (NSDictionary *)queryArgs callback
                  : (RCTResponseSenderBlock)callback) {
  HSMediaLibraryQuery *query = [HSMediaLibraryQuery fromDict:queryArgs];
  if (!query) {
    id error =
        RCTMakeError(@"Invalid query sent to MediaLibrary", queryArgs, nil);
    callback(@[ error, [NSNull null] ]);
    return;
  }
  NSArray<PHAsset *> *assets = [mediaLibrary loadAssets:query];
  NSMutableArray<NSDictionary *> *videos =
      [[NSMutableArray alloc] initWithCapacity:assets.count];
  [assets enumerateObjectsUsingBlock:^(PHAsset *_Nonnull asset, NSUInteger idx,
                                       BOOL *_Nonnull stop) {
    NSDictionary *video =
        @{ @"assetID" : asset.localIdentifier,
           @"duration" : @(asset.duration) };
    [videos insertObject:video atIndex:idx];
  }];
  callback(@[ [NSNull null], videos ]);
}

// TODO:

// RCT_EXPORT_METHOD(startObservingVideos) { [mediaLibrary
// startObservingVideos]; }

// RCT_EXPORT_METHOD(stopObservingVideos) { [mediaLibrary stopObservingVideos];
// }

@end
