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
    
    fileprivate var queuedAssets: [HLSAsset] = []

    /// Internal map of AVAggregateAssetDownloadTask to its corresponding Asset.
    fileprivate var pendingAssetsTaskMap = [AVAggregateAssetDownloadTask: HLSAsset]()
    
    /// Internal map of AVAggregateAssetDownloadTask to download URL.
    fileprivate var downloadURLTaskMap = [AVAggregateAssetDownloadTask: URL]()

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
                guard let assetDownloadTask = task as? AVAggregateAssetDownloadTask, let encodedAssetData = task.taskDescription else { break }
                
                let assetData = HLSAsset.decodeAssetDataFromString(encodedAssetData)
                
                let urlAsset = assetDownloadTask.urlAsset
            
                let asset = HLSAsset(
                    id: assetData.id,
                    hlsURL: assetData.hlsURL,
                    urlAsset: urlAsset,
                    status: HLSAsset.DownloadState.PENDING
                )
                 
                self.pendingAssetsTaskMap[assetDownloadTask] = asset
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
                "id": asset.id,
                "hlsUrl": asset.hlsURL,
                "bookmark": bookmark as Data
            ]
        )
        
        userDefaults.set(newData, forKey: AssetPersistenceManager.downloadedHlsDataKey)

    }
    
    func forgetDownloadedAssetData(_ id: String) {
        let userDefaults = UserDefaults.standard

        guard let currentData = userDefaults.value(
            forKey: AssetPersistenceManager.downloadedHlsDataKey
        ) as? [[String: Any]] else { return }
        
        userDefaults.removeObject(
            forKey: AssetPersistenceManager.downloadedHlsDataKey
        )
        
        let filteredData = currentData.filter {assetData in
            if let assetId = assetData["id"] as? String {
                return id.compare(assetId) != .orderedSame
            }
            return true
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
                
                if
                    let id = assetData["id"] as? String
                {
                    let asset = localAssetForStream(id)
                    
                    if (asset != nil) {
                        assets.append(asset!)
                    }
                }
                
               
            }
        }
        
        // Grab queued assets
        for asset in self.queuedAssets {
            assets.append(asset)
        }
        
        // Grab pending assets
        for (_, asset) in self.pendingAssetsTaskMap {
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
    
    func getHLSFileSize(_ directoryPath: String) -> Double {
        let properties: [URLResourceKey] = [.isRegularFileKey,
                                            .totalFileAllocatedSizeKey,
                                            /*.fileAllocatedSizeKey*/]

        guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: directoryPath),
                 includingPropertiesForKeys: properties,
                 options: .skipsHiddenFiles,
                 errorHandler: nil) else {
            return 0.0
        }

        let urls: [URL] = enumerator
            .compactMap { $0 as? URL }
            .filter { $0.absoluteString.contains(".frag") }

        let regularFileResources: [URLResourceValues] = urls
            .compactMap { try? $0.resourceValues(forKeys: Set(properties)) }
            .filter { $0.isRegularFile == true }

        let sizes: [Double] = regularFileResources
            .compactMap { $0.totalFileAllocatedSize! /* ?? $0.fileAllocatedSize */ }
            .compactMap { Double($0) }

        
        let size = sizes.reduce(0, +)
 
        return size
    }

    /// Triggers the initial AVAssetDownloadTask for a given Asset.
    /// - Tag: DownloadStream
    // MARK: Download stream
    @objc
    func downloadStream(_ id: String, hlsURL: String, bitrate: NSNumber) {
        // Check if this asset is already queued for download
        let queuedAsset = queuedAssetForStream(id)
        if (queuedAsset != nil) {
            return
        }
        
        // Check if this asset is already being downloaded
        let assetInProgress = pendingAssetForStream(id)
        if (
            assetInProgress != nil
        ) {
            return
        }
        
        // Check if this asset was already downloaded
        if (localAssetForStream(id) != nil) {
            return
        }
        
        // create new asset
        let urlAsset = AVURLAsset(url: URL(string: hlsURL)!)
        let asset = HLSAsset(
            id: id,
            hlsURL: hlsURL,
            urlAsset: urlAsset
        )
        
        queuedAssets.append(asset)
        
        sendHLSAssetsToJS()

        // Get the default media selections for the asset's media selection groups.
        let preferredMediaSelection = asset.urlAsset.preferredMediaSelection

        /*
         Creates and initializes an AVAggregateAssetDownloadTask to download multiple AVMediaSelections
         on an AVURLAsset.
        */
        guard let task =
            assetDownloadURLSession.aggregateAssetDownloadTask(
                with: asset.urlAsset,
                mediaSelections: [preferredMediaSelection],
                assetTitle: id,
                assetArtworkData: nil,
                options: [
                    AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: bitrate
                ]
            ) else { 
                return    
            }

        // To better track the AVAssetDownloadTask, set the taskDescription to something unique.
        task.taskDescription = asset.encodeAssetDataToString()
        
        print(task.countOfBytesExpectedToReceive);
        
        queuedAssets = queuedAssets.filter {$0 != asset}
        
        asset.status = HLSAsset.DownloadState.PENDING

        pendingAssetsTaskMap[task] = asset
        
        task.resume()

    }

    // MARK: Get asset
    /// Get pending (downloading) asset
    func pendingAssetForStream(_ id: String) -> HLSAsset? {
        var asset: HLSAsset?

        for (_, assetValue) in pendingAssetsTaskMap where id == assetValue.id {
            asset = assetValue
            break
        }

        return asset
    }
    
    /// Get idle (queued) asset
    func queuedAssetForStream(_ id: String) -> HLSAsset? {
        var asset: HLSAsset?

        for assetValue in queuedAssets where id == assetValue.id {
            asset = assetValue
            break
        }

        return asset
    }
        
    /// Returns an Asset pointing to a file on disk if it exists.
    func localAssetForStream(_ id: String) -> HLSAsset? {
        let userDefaults = UserDefaults.standard

        guard let assetsData = userDefaults.value(
            forKey: AssetPersistenceManager.downloadedHlsDataKey
        ) as? [[String: Any]] else { return nil }
        
        var assetData: [String: Any]?

        for assetDataItem in assetsData {
            if let assetId = assetDataItem["id"] as? String {
                if (
                    assetId.compare(id) == .orderedSame
                ) {
                    assetData = assetDataItem
                    break
                }
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
            
            let size = getHLSFileSize(urlAsset.url.path)
            
            let asset = HLSAsset(
                id: id,
                hlsURL: assetData!["hlsUrl"] as! String,
                urlAsset: urlAsset,
                status: HLSAsset.DownloadState.FINISHED,
                size: size
            )
            
            return asset
        } catch {
            forgetDownloadedAssetData(id)
            return nil
        }
       
    }

        
    @objc public static func urlAssetForStream(withURL hlsURL: String) -> AVURLAsset? {
        // Returns first matching urlAsset by hlsURL. 
        // For use by RCTVideo.m. Video player doesn't know the id of the video, and the only 
        // reason we use the id in other cases is to work around the stage env having the same
        // playlist url for every video. As such, it must not affect production, and even
        // on stage no one will notice the difference, since the underlying video asset is the 
        // same one anyway. 
        
        let userDefaults = UserDefaults.standard

        guard let assetsData = userDefaults.value(
            forKey: AssetPersistenceManager.downloadedHlsDataKey
        ) as? [[String: Any]] else { return nil }
        
        var assetData: [String: Any]?

        for assetDataItem in assetsData {
            let assetUrl = assetDataItem["hlsUrl"] as! String

            if (
                assetUrl.compare(hlsURL) == .orderedSame
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
          
            return urlAsset
        } catch {
            return nil
        }
    }

    /// Returns the current download state for a given Asset.
    func checkAssetFileExists(_ id: String) -> Bool {
        guard let hlsAsset = localAssetForStream(id) else { return false }
       
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
    func deleteAsset(_ id: String) {
        do {
           
            let hlsAsset = localAssetForStream(id)

            forgetDownloadedAssetData(id)
            
            sendHLSAssetsToJS()

            if (hlsAsset != nil) {
                try FileManager.default.removeItem(at: hlsAsset!.urlAsset.url)
            }
        } catch {
            print("An error occured deleting the file: \(error)")
        }
    }

    /// Cancels an AVAssetDownloadTask given an Asset.
    /// - Tag: CancelDownload
    @objc
    func cancelDownload(_ id: String) {
        guard let asset = pendingAssetForStream(id) else { return }
        var task: AVAggregateAssetDownloadTask?

        for (taskKey, assetVal) in pendingAssetsTaskMap where asset == assetVal {
            task = taskKey
            break
        }

        if (task != nil) {
            task!.cancel()
            pendingAssetsTaskMap.removeValue(forKey: task!)
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
            let asset = pendingAssetsTaskMap.removeValue(forKey: task) else { return }

        guard let downloadURL = downloadURLTaskMap.removeValue(forKey: task) else { return }

        
        
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
                       asset.id
                    )?.urlAsset.url else { return }

                    do {
                        try FileManager.default.removeItem(at: localFileLocation)
                    } catch {
                        print("An error occured trying to delete the contents on disk for \(asset.id): \(error)")
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

        downloadURLTaskMap[aggregateAssetDownloadTask] = location
    }

    /// Method called when a child AVAssetDownloadTask completes.
    public func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
                    didCompleteFor mediaSelection: AVMediaSelection) {
        /*
         This delegate callback provides an AVMediaSelection object which is now fully available for
         offline use. You can perform any additional processing with the object here.
         */

        guard let asset = pendingAssetsTaskMap[aggregateAssetDownloadTask] else { return }

        aggregateAssetDownloadTask.taskDescription = asset.encodeAssetDataToString()

        aggregateAssetDownloadTask.resume()
    }

    /// Method to adopt to subscribe to progress updates of an AVAggregateAssetDownloadTask.
    public func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
                    didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                    timeRangeExpectedToLoad: CMTimeRange, for mediaSelection: AVMediaSelection) {

        // This delegate callback should be used to provide download progress for your AVAssetDownloadTask.
        guard let asset = pendingAssetsTaskMap[aggregateAssetDownloadTask] else { return }

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
