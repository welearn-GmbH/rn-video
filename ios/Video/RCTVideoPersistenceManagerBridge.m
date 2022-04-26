#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>
#import "React/RCTEventEmitter.h"

@interface RCT_EXTERN_MODULE(AssetPersistenceManager, NSObject)

RCT_EXTERN_METHOD(downloadStream:(NSString)name hlsURL:(NSString)hlsURL)
RCT_EXTERN_METHOD(deleteAsset:(NSString)name hlsURL:(NSString)hlsURL)
RCT_EXTERN_METHOD(cancelDownload:(NSString)name hlsURL:(NSString)hlsURL)
RCT_EXTERN_METHOD(
    getHLSAssetsForJS: (RCTPromiseResolveBlock)resolve
    rejecter: (RCTPromiseRejectBlock)reject
)

@end


@interface RCT_EXTERN_MODULE(AssetPersistenceEventEmitter, RCTEventEmitter)
@end


