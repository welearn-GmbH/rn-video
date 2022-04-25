import Foundation
import AVFoundation

/// - Tag: AssetPersistenceManager
@objc(AssetPersistenceManager)
public class AssetPersistenceManager: NSObject {
    // MARK: Properties

    /// Singleton for AssetPersistenceManager.
    static let sharedManager = AssetPersistenceManager()
    
    private var hlsAssets: [HLSAsset] = []
    
    static let downloadedHlsUrlsKey = "DownloadedHLSUrls"

    /// Internal Bool used to track if the AssetPersistenceManager finished restoring its state.
    private var didRestorePersistenceManager = false

    /// The AVAssetDownloadURLSession to use for managing AVAssetDownloadTasks.
    fileprivate var assetDownloadURLSession: AVAssetDownloadURLSession!

    /// Internal map of AVAggregateAssetDownloadTask to its corresponding Asset.
    fileprivate var activeDownloadsMap = [AVAggregateAssetDownloadTask: HLSAsset]()
    
    /// Internal map of AVAggregateAssetDownloadTask to its corresponding Asset.
    fileprivate var failedDownloads = [HLSAsset]()

    /// Internal map of AVAggregateAssetDownloadTask to download URL.
    fileprivate var willDownloadToUrlMap = [AVAggregateAssetDownloadTask: URL]()

    // MARK: Intialization

    override private init() {

        super.init()

        // Create the configuration for the AVAssetDownloadURLSession.
        let backgroundConfiguration = URLSessionConfiguration.background(withIdentifier: "AAPL-Identifier")

        // Create the AVAssetDownloadURLSession using the configuration.
        assetDownloadURLSession =
            AVAssetDownloadURLSession(configuration: backgroundConfiguration,
                                      assetDownloadDelegate: self, delegateQueue: OperationQueue.main)
        
        restorePersistenceManager()
    }
    
    /// Restores the Application state by getting all the AVAssetDownloadTasks and restoring their Asset structs.
    func restorePersistenceManager() {
        guard !didRestorePersistenceManager else { return }
        
        didRestorePersistenceManager = true
        
        // Grab all the tasks associated with the assetDownloadURLSession
        assetDownloadURLSession.getAllTasks { tasksArray in
            // For each task, restore the state in the app by recreating Asset structs and reusing existing AVURLAsset objects.
            for task in tasksArray {
                guard let assetDownloadTask = task as? AVAggregateAssetDownloadTask, let assetData = task.taskDescription else { break }
                
                let metadata = MetadataParser(assetData)
                
                let urlAsset = assetDownloadTask.urlAsset
            
                let asset = HLSAsset(
                    name: metadata.name,
                    hlsURL: metadata.hlsURL,
                    urlAsset: urlAsset,
                    status: HLSAsset.DownloadState.PENDING
                )
                
                self.activeDownloadsMap[assetDownloadTask] = asset
            }
        }

        sendHLSAssetsToJS()
    }

    // MARK: Implementation
    
    @objc
    func saveDownloadedAssetUrl(url: String) {
        let userDefaults = UserDefaults.standard
        
        var assetsUrls: [String] = []
        
        let currentUrls = userDefaults.value(
            forKey: AssetPersistenceManager.downloadedHlsUrlsKey
        ) as? [String]
        
        if (currentUrls != nil) {
            assetsUrls = currentUrls!
        }
        
        userDefaults.removeObject(
            forKey: AssetPersistenceManager.downloadedHlsUrlsKey
        )
        
        assetsUrls.append(url)
        
        userDefaults.set(assetsUrls, forKey: AssetPersistenceManager.downloadedHlsUrlsKey)
    }
    
    @objc
    func forgetDownloadedAssetUrl(url: String) {
        let userDefaults = UserDefaults.standard
        
        guard let assetsUrls = userDefaults.value(
            forKey: AssetPersistenceManager.downloadedHlsUrlsKey
        ) as? [String] else { return }
        
        userDefaults.removeObject(
            forKey: AssetPersistenceManager.downloadedHlsUrlsKey
        )
        
        let filtered = assetsUrls.filter {hlsUrl in
            return hlsUrl != url
        }
        
        userDefaults.set(filtered, forKey: AssetPersistenceManager.downloadedHlsUrlsKey)
        userDefaults.removeObject(forKey: url)
    }
    
    @objc
    func collectHLSAssetsData() -> NSMutableArray {
        var assets:[HLSAsset] = []
        
        // Grab and parse urls of downloaded assets
        let userDefaults = UserDefaults.standard
        
        let downloadedHlsURLs = userDefaults.value(forKey: AssetPersistenceManager.downloadedHlsUrlsKey) as? [String]
        
        if (downloadedHlsURLs != nil) {
            for hlsUrl in downloadedHlsURLs! {
                let asset = localAssetForStream(withURL: hlsUrl)
                if (asset != nil && checkAssetFileExists(asset!.hlsURL)) {
                    assets.append(asset!)
                }
            }
        }
        
        // Grab pending assets
        for (_, asset) in self.activeDownloadsMap {
            assets.append(asset)
        }
        
        // Construct data array
        let body: NSMutableArray = []
        
        for asset in assets {
            let assetData: NSMutableDictionary = [:]
            assetData["name"] = asset.name
            assetData["hlsUrl"] = asset.hlsURL
            assetData["progress"] = asset.progress
            assetData["status"] = asset.status.rawValue
            body.add(assetData)
        }
        
        return body
    }
    
    @objc(getHLSAssetsForJS:rejecter:)
    func getHLSAssetsForJS(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
        let assets = collectHLSAssetsData()
        resolve(assets)
    }

    @objc
    func sendHLSAssetsToJS() {
        let assetsData = collectHLSAssetsData()
        AssetPersistenceEventEmitter.shared?.sendCustomEvent(body: assetsData)
    }

    /// Triggers the initial AVAssetDownloadTask for a given Asset.
    /// - Tag: DownloadStream
    // MARK: Download stream
    @objc
    func downloadStream(_ name: String, hlsURL: String) {
        
        // Check if this asset is already downloaded
        if (
            assetForStream(withURL: hlsURL) != nil ||
            localAssetForStream(withURL: hlsURL) != nil
        ) {
            deleteAsset(hlsURL)
            return
        }
        
        // create new asset
        let urlAsset = AVURLAsset(url: URL(string: hlsURL)!)
        let asset = HLSAsset(
            name: name,
            hlsURL: hlsURL,
            urlAsset: urlAsset,
            status: HLSAsset.DownloadState.PENDING
        )

        // Get the default media selections for the asset's media selection groups.
        let preferredMediaSelection = asset.urlAsset.preferredMediaSelection

        /*
         Creates and initializes an AVAggregateAssetDownloadTask to download multiple AVMediaSelections
         on an AVURLAsset.
         
         For the initial download, we ask the URLSession for an AVAssetDownloadTask with a minimum bitrate
         corresponding with one of the lower bitrate variants in the asset.
         */
        guard let task =
            assetDownloadURLSession.aggregateAssetDownloadTask(with: asset.urlAsset,
                                                               mediaSelections: [preferredMediaSelection],
                                                               assetTitle: asset.name,
                                                               assetArtworkData: nil,
                                                               options:
                [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 265_000]) else { return }

        // To better track the AVAssetDownloadTask, set the taskDescription to something unique.
        task.taskDescription = MetadataParser.genMetadata(asset)

        activeDownloadsMap[task] = asset

        task.resume()
    }

    // MARK: Get asset
    /// Returns an Asset given a specific name if that Asset is associated with an active download.
    func assetForStream(withURL hlsURL: String) -> HLSAsset? {
        var asset: HLSAsset?

        for (_, assetValue) in activeDownloadsMap where hlsURL == assetValue.hlsURL {
            asset = assetValue
            break
        }

        return asset
    }
    
    /// Returns an Asset pointing to a file on disk if it exists.
    func localAssetForStream(withURL hlsURL: String) -> HLSAsset? {
        let userDefaults = UserDefaults.standard
        guard let localFileData = userDefaults.value(forKey: hlsURL) as? [String:Any] else { return nil }
        
        let bookmark = localFileData["bookmark"] as! Data
        let name = localFileData["name"] as! String
        
        var asset: HLSAsset?
        var bookmarkDataIsStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmark,
                                    bookmarkDataIsStale: &bookmarkDataIsStale)

            if bookmarkDataIsStale {
                fatalError("Bookmark data is stale!")
            }
            
            let urlAsset = AVURLAsset(url: url)
            
            asset = HLSAsset(
                name: name,
                hlsURL: hlsURL,
                urlAsset: urlAsset,
                status: HLSAsset.DownloadState.FINISHED
            )
            
            return asset
        } catch {
            return nil
        }
    }

    /// Returns the current download state for a given Asset.
    func checkAssetFileExists(_ hlsURL: String) -> Bool {
        
        // Check if there is a file URL stored for this asset.
        if let localFileLocation = localAssetForStream(withURL: hlsURL)?.urlAsset.url {
            // Check if the file exists on disk
            if FileManager.default.fileExists(atPath: localFileLocation.path) {
                return true
            }
        }

        return false
    }

    // MARK: Delete asset
    /// Deletes an Asset on disk if possible.
    /// - Tag: RemoveDownload
    @objc
    func deleteAsset(_ hlsURL: String) {
        do {
            if let localFileLocation = localAssetForStream(withURL: hlsURL)?.urlAsset.url {
                try FileManager.default.removeItem(at: localFileLocation)
                
                forgetDownloadedAssetUrl(url: hlsURL)
                
                sendHLSAssetsToJS()
            }
        } catch {
            print("An error occured deleting the file: \(error)")
        }
    }

    /// Cancels an AVAssetDownloadTask given an Asset.
    /// - Tag: CancelDownload
    @objc
    func cancelDownload(_ hlsURL: String) {
        var task: AVAggregateAssetDownloadTask?

        guard let task = task as? AVAggregateAssetDownloadTask,
            let asset = activeDownloadsMap.removeValue(forKey: task) else { return }

        task.cancel()
        
        sendHLSAssetsToJS()
        
    }
}

/// Return the display names for the media selection options that are currently selected in the specified group
func displayNamesForSelectedMediaOptions(_ mediaSelection: AVMediaSelection) -> String {

    var displayNames = ""

    guard let asset = mediaSelection.asset else {
        return displayNames
    }

    // Iterate over every media characteristic in the asset in which a media selection option is available.
    for mediaCharacteristic in asset.availableMediaCharacteristicsWithMediaSelectionOptions {
        /*
         Obtain the AVMediaSelectionGroup object that contains one or more options with the
         specified media characteristic, then get the media selection option that's currently
         selected in the specified group.
         */
        guard let mediaSelectionGroup =
            asset.mediaSelectionGroup(forMediaCharacteristic: mediaCharacteristic),
            let option = mediaSelection.selectedMediaOption(in: mediaSelectionGroup) else { continue }

        // Obtain the display string for the media selection option.
        if displayNames.isEmpty {
            displayNames += " " + option.displayName
        } else {
            displayNames += ", " + option.displayName
        }
    }

    return displayNames
}

// MARK: AVAssetDownloadDelegate

/**
 Extend `AssetPersistenceManager` to conform to the `AVAssetDownloadDelegate` protocol.
 */
extension AssetPersistenceManager: AVAssetDownloadDelegate {

    /// Tells the delegate that the task finished transferring data.
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let userDefaults = UserDefaults.standard

        /*
         This is the ideal place to begin downloading additional media selections
         once the asset itself has finished downloading.
         */
        guard let task = task as? AVAggregateAssetDownloadTask,
            let asset = activeDownloadsMap.removeValue(forKey: task) else { return }

        guard let downloadURL = willDownloadToUrlMap.removeValue(forKey: task) else { return }

        if let error = error as NSError? {
            asset.status = HLSAsset.DownloadState.FAILED
            
            sendHLSAssetsToJS()
            
            switch (error.domain, error.code) {
            case (NSURLErrorDomain, NSURLErrorCancelled):
                /*
                 This task was canceled, perform cleanup using the
                 URL saved from AVAssetDownloadDelegate.urlSession(_:assetDownloadTask:didFinishDownloadingTo:).
                 */
                guard let localFileLocation = localAssetForStream(withURL: asset.hlsURL)?.urlAsset.url else { return }

                do {
                    try FileManager.default.removeItem(at: localFileLocation)
                    forgetDownloadedAssetUrl(url: asset.hlsURL)
                } catch {
                    print("An error occured trying to delete the contents on disk for \(asset.name): \(error)")
                }

            case (NSURLErrorDomain, NSURLErrorUnknown):
                fatalError("Downloading HLS streams is not supported in the simulator.")

            default:
                fatalError("An unexpected error occured \(error.domain)")
            }
        } else {
            do {
                asset.status = HLSAsset.DownloadState.FINISHED
                let bookmark = try downloadURL.bookmarkData()
                
                var data = [String:Any]()
                data["name"] = asset.name
                data["hlsURL"] = asset.hlsURL
                data["bookmark"] = bookmark
                
                userDefaults.set(data, forKey: asset.hlsURL)
                saveDownloadedAssetUrl(url: asset.hlsURL)

                sendHLSAssetsToJS()
            } catch {
                print("Failed to create bookmarkData for download URL.")
            }
        }
    }

    /// Method called when the an aggregate download task determines the location this asset will be downloaded to.
    public func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
                    willDownloadTo location: URL) {

        /*
         This delegate callback should only be used to save the location URL
         somewhere in your application. Any additional work should be done in
         `URLSessionTaskDelegate.urlSession(_:task:didCompleteWithError:)`.
         */

        willDownloadToUrlMap[aggregateAssetDownloadTask] = location
    }

    /// Method called when a child AVAssetDownloadTask completes.
    public func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
                    didCompleteFor mediaSelection: AVMediaSelection) {
        /*
         This delegate callback provides an AVMediaSelection object which is now fully available for
         offline use. You can perform any additional processing with the object here.
         */

        guard let asset = activeDownloadsMap[aggregateAssetDownloadTask] else { return }

        aggregateAssetDownloadTask.taskDescription = MetadataParser.genMetadata(asset)

        aggregateAssetDownloadTask.resume()
    }

    /// Method to adopt to subscribe to progress updates of an AVAggregateAssetDownloadTask.
    public func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
                    didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                    timeRangeExpectedToLoad: CMTimeRange, for mediaSelection: AVMediaSelection) {

        // This delegate callback should be used to provide download progress for your AVAssetDownloadTask.
        guard let asset = activeDownloadsMap[aggregateAssetDownloadTask] else { return }

        var percentComplete = 0.0
        for value in loadedTimeRanges {
            let loadedTimeRange: CMTimeRange = value.timeRangeValue
            percentComplete +=
                loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds
        }
        
        asset.progress = percentComplete
        
        sendHLSAssetsToJS()
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

// MARK: Metadata Parser

class MetadataParser {
    static let METADATA_SEPARATOR =  "***ayylmao***"
    
    static func genMetadata(_ hlsAsset: HLSAsset) -> String {
        return hlsAsset.name + MetadataParser.METADATA_SEPARATOR + hlsAsset.hlsURL
    }
    
    init(_ metadata: String) {
        let arr = metadata.components(separatedBy: MetadataParser.METADATA_SEPARATOR)
        name = arr[0]
        hlsURL = arr[1]
    }
    
    let name: String
    let hlsURL: String
    
}
