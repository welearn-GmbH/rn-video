import Foundation
import AVFoundation

// MARK: Persistence Manager

@objc(AssetPersistenceManager)
public class AssetPersistenceManager: NSObject {
    /// Singleton for AssetPersistenceManager.
    let persistenceController = AssetPersistenceController.sharedManager
    
    @objc
    public static func urlAssetForStream(withURL hlsURL: String) -> AVURLAsset? {
        return  AssetPersistenceController.sharedManager.urlAssetForStream(withURL: hlsURL)
    }
    
    @objc
    public func deleteAsset(_ id: String) {
        persistenceController.deleteAsset(id)
    }


    @objc
    public func cancelDownload(_ id: String) {
        persistenceController.cancelDownload(id)
    }
    
    @objc
    public func downloadStream(_ id: String, hlsURL: String, bitrate: NSNumber) {
        persistenceController.downloadStream(id, hlsURL: hlsURL, bitrate: bitrate)
    }
    
    @objc
    public func getHLSAssetsForJS(
        _ resolve: RCTPromiseResolveBlock,
        rejecter reject: RCTPromiseRejectBlock
    ) {
        persistenceController.getHLSAssetsForJS(resolve, rejecter: reject)
    }
}

// MARK: Event Emitter

@objc(AssetPersistenceEventEmitter)
class AssetPersistenceEventEmitter: RCTEventEmitter {
    public static var shared: AssetPersistenceEventEmitter?
    
    override init() {
        super.init()
        AssetPersistenceEventEmitter.shared = self
    }
    
    static let hlsDownloadsJSEventName = "hlsDownloads"
    
    override public func supportedEvents() -> [String]! {
        return [
            AssetPersistenceEventEmitter.hlsDownloadsJSEventName,
        ]
    }
    
    public func sendCustomEvent(body: Any) {
        sendEvent(
            withName: AssetPersistenceEventEmitter.hlsDownloadsJSEventName,
            body: body
        )
    }
}
