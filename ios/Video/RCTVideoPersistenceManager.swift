import Foundation
import AVFoundation

/// - Tag: AssetPersistenceManager
@objc(AssetPersistenceManager)
public class AssetPersistenceManager: NSObject {
    // MARK: Properties

    /// Singleton for AssetPersistenceManager.
    static let sharedManager = AssetPersistenceManager()
    
    static let downloadedHlsDataKey = "DownloadedHLSData"

    /// Internal Bool used to track if the AssetPersistenceManager finished restoring its state.
    private var didRestorePersistenceManager = false

    /// The AVAssetDownloadURLSession to use for managing AVAssetDownloadTasks.
    fileprivate var assetDownloadURLSession: AVAssetDownloadURLSession!
    
    fileprivate var queuedDownloads: [HLSAsset] = []

    /// Internal map of AVAggregateAssetDownloadTask to its corresponding Asset.
    fileprivate var activeDownloadsMap = [AVAggregateAssetDownloadTask: HLSAsset]()
    
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
                guard let assetDownloadTask = task as? AVAggregateAssetDownloadTask, let streamIdString = task.taskDescription else { break }
                
                let metadata = HLSAsset.parseStreamIdString(streamId: streamIdString)
                
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
    }

    // MARK: Implementation
    
    func saveDownloadedAssetData(asset: HLSAsset, bookmark: Data) {
        let userDefaults = UserDefaults.standard
        
        var newData: [[String: Any]] = []
        
        let currentData = userDefaults.value(
            forKey: AssetPersistenceManager.downloadedHlsDataKey
        ) as? [[String: Any]]

        if (currentData != nil) {
            newData = currentData!
        }
        
        userDefaults.removeObject(
            forKey: AssetPersistenceManager.downloadedHlsDataKey
        )
        
        newData.append(
            [
                "name": asset.name,
                "hlsUrl": asset.hlsURL,
                "bookmark": bookmark as Data
            ]
        )
        
        userDefaults.set(newData, forKey: AssetPersistenceManager.downloadedHlsDataKey)

    }
    
    func forgetDownloadedAssetData(withURL hlsURL: String, name:String) {
        let userDefaults = UserDefaults.standard

        guard let currentData = userDefaults.value(
            forKey: AssetPersistenceManager.downloadedHlsDataKey
        ) as? [[String: Any]] else { return }
        
        userDefaults.removeObject(
            forKey: AssetPersistenceManager.downloadedHlsDataKey
        )
        
        let filteredData = currentData.filter {assetData in
            let assetURL = assetData["hlsUrl"] as! String
            let assetName = assetData["name"] as! String
            return hlsURL.compare(assetURL) != .orderedSame &&
                name.compare(assetName) != .orderedSame
        }
        
        userDefaults.set(filteredData, forKey: AssetPersistenceManager.downloadedHlsDataKey)
    }
    
    @objc
    func collectHLSAssetsData() -> NSMutableArray {
        var assets:[HLSAsset] = []
        
        // Grab and parse urls of downloaded assets
        let userDefaults = UserDefaults.standard
        
        let downloadedAssetsData = userDefaults.value(forKey: AssetPersistenceManager.downloadedHlsDataKey) 
        as? [[String: Any]]
        
        if (downloadedAssetsData != nil) {
            for assetData in downloadedAssetsData! {
                let hlsURL = assetData["hlsUrl"] as! String
                let name = assetData["name"] as! String
                let bookmark = assetData["bookmark"] as! Data
                
                let asset = localAssetForStream(
                    withURL: hlsURL,
                    name: name,
                    bookmark: bookmark
                )
                
                if (asset != nil) {
                    assets.append(asset!)
                }
            }
        }
        
        // Grab queued assets
        for asset in self.queuedDownloads {
            assets.append(asset)
        }
        
        // Grab pending assets
        for (_, asset) in self.activeDownloadsMap {
            assets.append(asset)
        }
        
        // Construct data array
        let body: NSMutableArray = []
        
        for asset in assets {
            body.add(asset.formattedDataJS())
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
        // CHeck if this asset is already queued for download
        let queuedAsset = queuedAssetForStream(withURL: hlsURL, name: name)
        if (queuedAsset != nil) {
            return
        }
        
        // Check if this asset is already being downloaded
        let assetInProgress = assetForStream(withURL: hlsURL, name: name)
        if (
            assetInProgress != nil
        ) {
            //cancelDownload(name, hlsURL: hlsURL)
            return
        }
        
        // Check if this asset was already downloaded
        if (localAssetForStream(withURL: hlsURL, name: name) != nil) {
            // deleteAsset(name, hlsURL: hlsURL)
            return
        }
        
        // create new asset
        let urlAsset = AVURLAsset(url: URL(string: hlsURL)!)
        let asset = HLSAsset(
            name: name,
            hlsURL: hlsURL,
            urlAsset: urlAsset,
            status: HLSAsset.DownloadState.IDLE
        )
        
        queuedDownloads.append(asset)
        
        sendHLSAssetsToJS()

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
        task.taskDescription = asset.streamIdString()
        
        queuedDownloads = queuedDownloads.filter {$0 != asset}
        
        asset.status = HLSAsset.DownloadState.PENDING

        activeDownloadsMap[task] = asset
        
        task.resume()

    }

    // MARK: Get asset
    /// Returns an Asset given a specific name if that Asset is associated with an active download.
    func assetForStream(withURL hlsURL: String, name: String) -> HLSAsset? {
        var asset: HLSAsset?

        for (_, assetValue) in activeDownloadsMap where hlsURL == assetValue.hlsURL && name == assetValue.name {
            asset = assetValue
            break
        }

        return asset
    }
    
    func queuedAssetForStream(withURL hlsURL: String, name: String) -> HLSAsset? {
        var asset: HLSAsset?

        for assetValue in queuedDownloads where hlsURL == assetValue.hlsURL && name == assetValue.name {
            asset = assetValue
            break
        }

        return asset
    }
    
    /// Returns an Asset pointing to a file on disk if it exists.
    func localAssetForStream(withURL hlsURL: String, name: String, bookmark: Data? = nil) -> HLSAsset? {
        if let providedBookmark = bookmark {
            // Bookmark provided - try to load asset from file directly

            var bookmarkDataIsStale = false
            do {
                let url = try URL(resolvingBookmarkData: providedBookmark,
                                        bookmarkDataIsStale: &bookmarkDataIsStale)

                if bookmarkDataIsStale {
                    fatalError("Bookmark data is stale!")
                }
                
                let urlAsset = AVURLAsset(url: url)
                
                let asset = HLSAsset(
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

        // No bookmark - find asset data in user defaults and load from file

        let userDefaults = UserDefaults.standard

        guard let assetsData = userDefaults.value(
            forKey: AssetPersistenceManager.downloadedHlsDataKey
        ) as? [[String: Any]] else { return nil }
        
        var assetData: [String: Any]?

        for assetDataItem in assetsData {
            let assetUrl = assetDataItem["hlsUrl"] as! String
            let assetName = assetDataItem["name"] as! String

            if (
                assetUrl.compare(hlsURL) == .orderedSame &&
                assetName.compare(name) == .orderedSame
            ) {
                assetData = assetDataItem
                break
            }
        }

        if (assetData == nil) {
            return nil
        }
        
        let bookmark = assetData!["bookmark"] as! Data
        var bookmarkDataIsStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmark,
                                    bookmarkDataIsStale: &bookmarkDataIsStale)

            if bookmarkDataIsStale {
                fatalError("Bookmark data is stale!")
            }
            
            let urlAsset = AVURLAsset(url: url)
            
            let asset = HLSAsset(
                name: name,
                hlsURL: hlsURL,
                urlAsset: urlAsset,
                status: HLSAsset.DownloadState.FINISHED
            )
            
            return asset
        } catch {
            forgetDownloadedAssetData(withURL: hlsURL, name: name)
            return nil
        }
       
    }

    /// Returns the current download state for a given Asset.
    func checkAssetFileExists(_ hlsURL: String, name: String) -> Bool {
        guard let hlsAsset = localAssetForStream(withURL: hlsURL, name: name) else { return false }
       
        // Check if there is a file URL stored for this asset.
        if FileManager.default.fileExists(atPath: hlsAsset.urlAsset.url.path) {
            return true
        }

        return false
    }

    // MARK: Delete asset
    /// Deletes an Asset on disk if possible.
    /// - Tag: RemoveDownload
    @objc
    func deleteAsset(_ name: String, hlsURL: String) {
        do {
            forgetDownloadedAssetData(withURL: hlsURL, name: name)
            
            sendHLSAssetsToJS()
            
            guard let hlsAsset = localAssetForStream(withURL: hlsURL, name: name) else { return }

            try FileManager.default.removeItem(at: hlsAsset.urlAsset.url)
        } catch {
            print("An error occured deleting the file: \(error)")
        }
    }

    /// Cancels an AVAssetDownloadTask given an Asset.
    /// - Tag: CancelDownload
    @objc
    func cancelDownload(_ name: String, hlsURL: String) {
        guard let asset = assetForStream(withURL: hlsURL, name: name) else { return }
        var task: AVAggregateAssetDownloadTask?

        for (taskKey, assetVal) in activeDownloadsMap where asset == assetVal {
            task = taskKey
            break
        }

        if (task != nil) {
            task!.cancel()
            activeDownloadsMap.removeValue(forKey: task!)
            sendHLSAssetsToJS()
        }
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
                    guard let localFileLocation = localAssetForStream(
                        withURL: asset.hlsURL,
                        name:asset.name
                    )?.urlAsset.url else { return }

                    do {
                        try FileManager.default.removeItem(at: localFileLocation)
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
                saveDownloadedAssetData(asset: asset, bookmark: bookmark as Data)
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

        aggregateAssetDownloadTask.taskDescription = asset.streamIdString()

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
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print(error)
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
