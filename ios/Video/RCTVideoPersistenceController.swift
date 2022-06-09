import Foundation
import AVFoundation


public class AssetPersistenceController: NSObject {
    // MARK: Properties

    /// Singleton for AssetPersistenceManager.
    static let sharedManager = AssetPersistenceController()
    
    static let downloadedHlsDataKey = "DownloadedHLSData"

    /// Internal Bool used to track if the AssetPersistenceManager finished restoring its state.
    private var didRestorePersistenceController = false

    fileprivate var userDefaults = UserDefaults.standard
    
    /// The AVAssetDownloadURLSession to use for managing AVAssetDownloadTasks.
    fileprivate var assetDownloadURLSession: AVAssetDownloadURLSession!
    
    fileprivate var assets = [String: HLSAsset]()
    fileprivate var tasks = [String: AVAggregateAssetDownloadTask]()
    fileprivate var downloadUrls = [String: URL]()
    fileprivate var desiredBitrate: NSNumber = 10_000_000

    // MARK: Initialization
    override init() {

        super.init()

        // Create the configuration for the AVAssetDownloadURLSession.
        let backgroundConfiguration = URLSessionConfiguration.background(withIdentifier: "AAPL-Identifier")


        // Create the AVAssetDownloadURLSession using the configuration.
        assetDownloadURLSession =
            AVAssetDownloadURLSession(configuration: backgroundConfiguration,
                                      assetDownloadDelegate: self, delegateQueue: OperationQueue.main)
        
        
        restorePersistenceManager()
    }
    
    func restorePersistenceManager() {
        guard !didRestorePersistenceController else { return }
        
        didRestorePersistenceController = true
        
        // Restore all tasks associated with the assetDownloadURLSession
        assetDownloadURLSession.getAllTasks { tasksArray in
            for task in tasksArray {
                guard let assetDownloadTask = task as? AVAggregateAssetDownloadTask, let id = task.taskDescription else { break }
                
                // let urlAsset = assetDownloadTask.urlAsset

                self.tasks[id] = assetDownloadTask
            }
            
            // Restore all saved assets data from UserDefaults
            guard let jsonString = self.userDefaults.value(
                forKey: AssetPersistenceController.downloadedHlsDataKey
            ) as? Data else {
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let hlsAssets = try decoder.decode(
                    [String: HLSAssetData].self,
                    from: jsonString
                )
                for (id, hlsAssetData) in hlsAssets {
                    let asset = HLSAsset(
                        id: hlsAssetData.id,
                        hlsURL: hlsAssetData.hlsURL,
                        bookmark: hlsAssetData.bookmark,
                        status: HLSAsset.DownloadState.init(
                            rawValue: hlsAssetData.status
                        )!,
                        size: hlsAssetData.size
                    )
                    self.assets[id] = asset
                    if (asset.status == HLSAsset.DownloadState.PENDING && self.tasks[asset.id] == nil) {
                        // Download task was not recovered - delete leftover
                        // data and recreate the task
                        let url = asset.getURLAsset()?.url
                        if (url != nil) {
                            do {
                                try FileManager.default.removeItem(at: url!)
                            } catch {
                                print("Couldn't delete leftover data: \(error)")
                            }
                        }
                        self.createDownloadTaskForAsset(asset)
                    }
                }
                self.checkQueue()
            } catch {
                fatalError("Failed to parse json asset: \(error)")
            }
        }
    }


    // MARK: Asset data management
    
    func saveAssetData(asset: HLSAsset) {
        assets[asset.id] = asset
        sendHLSAssetsToJS()
        saveAssetsToStorage()
    }
    
    func deleteAssetData(_ id: String) {
        assets.removeValue(forKey: id)
        sendHLSAssetsToJS()
        saveAssetsToStorage()
    }
    
    func saveAssetsToStorage() {
        let encoder = JSONEncoder()
        let assetsData:[String:HLSAssetData] = assets.reduce([:]) {
            (partialResult: [String: HLSAssetData], tuple: (key:String, value:HLSAsset)) in
                var result = partialResult
                let asset = tuple.value
                let id = tuple.key
                result[id] = HLSAssetData(
                    id: asset.id,
                    hlsURL: asset.hlsURL,
                    size: asset.size,
                    status:asset.status.rawValue,
                    bookmark: asset.bookmark
                )
                return result
        }
        do {
            let json = try encoder.encode(assetsData)
            userDefaults.set(
                json,
                forKey: AssetPersistenceController.downloadedHlsDataKey
            )
        } catch {
            print("Failed to jsonify assets: \(error)")
        }
       
    }
    
 
    func collectHLSAssetsData() -> NSMutableArray {
        let body: NSMutableArray = []
        
        for (_, asset) in assets {
            body.add(asset.formattedDataJS())
        }
        
        return body
    }
    

    func getHLSAssetsForJS(
        _ resolve: RCTPromiseResolveBlock,
        rejecter reject: RCTPromiseRejectBlock
    ) {
        let assets = collectHLSAssetsData()
        resolve(assets)
    }


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
    func downloadStream(_ id: String, hlsURL: String, bitrate: NSNumber) {
        let existingAsset = assets[id]
        if (
            existingAsset != nil &&
            existingAsset?.status != HLSAsset.DownloadState.FAILED
        ) {
            return
        }
        
        let asset = HLSAsset(
            id: id,
            hlsURL: hlsURL
        )
        saveAssetData(asset: asset)
        
        desiredBitrate = bitrate
        
        checkQueue()
    }
    
    func checkQueue() {
        var amountDownloading = 0
        for (_, asset) in assets {
            if (asset.status == HLSAsset.DownloadState.PENDING) {
                amountDownloading += 1
            }
        }
        if (amountDownloading >= 1) {
            return
        }
        for (_, asset) in assets {
            if (asset.status == HLSAsset.DownloadState.IDLE) {
                createDownloadTaskForAsset(asset)
                break
            }
        }
    }
    
    func createDownloadTaskForAsset(_ asset: HLSAsset) {
        let urlAssetToDownload = AVURLAsset(url: URL(string: asset.hlsURL)!)
        let preferredMediaSelection = urlAssetToDownload.preferredMediaSelection

        guard let task =
            assetDownloadURLSession.aggregateAssetDownloadTask(
                with: urlAssetToDownload,
                mediaSelections: [preferredMediaSelection],
                assetTitle: asset.id,
                assetArtworkData: nil,
                options: [
                    AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: desiredBitrate,
                ]
            ) else {
                return
            }
        
        task.taskDescription = asset.id
        tasks[asset.id] = task
        
        asset.status = HLSAsset.DownloadState.PENDING
        saveAssetData(asset: asset)
        
        task.resume()
    }

    // MARK: Get asset

        
    public func urlAssetForStream(withURL hlsURL: String) -> AVURLAsset? {
        for (_, asset) in assets {
            if (asset.hlsURL == hlsURL) {
                return asset.getURLAsset()
            }
        }
        return nil
    }

    // MARK: Delete asset
    
    func deleteAsset(_ id: String) {
        guard let url = assets[id]?.getURLAsset()?.url else {
            return
        }
        
        deleteAssetData(id)
        
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("An error occured deleting the file: \(error)")
        }
    }

    // MARK: Cancel download

    func cancelDownload(_ id: String) {
        tasks[id]?.cancel()
        tasks.removeValue(forKey: id)
        checkQueue()
    }
}



/**
 Extend `AssetPersistenceController` to conform to the `AVAssetDownloadDelegate` protocol.
 */
extension AssetPersistenceController: AVAssetDownloadDelegate {

    
    // MARK: Download finished
    
    /// Tells the delegate that the task finished transferring data.
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        /*
         This is the ideal place to begin downloading additional media selections
         once the asset itself has finished downloading.
         */
        guard let task = task as? AVAggregateAssetDownloadTask,
              let id = task.taskDescription,
              let asset = assets[id] else { return }

        guard let downloadURL = downloadUrls.removeValue(forKey: id) else { return }

        if let error = error as NSError? {
            asset.status = HLSAsset.DownloadState.FAILED
            saveAssetData(asset: asset)
            
            switch (error.domain, error.code) {
                case (NSURLErrorDomain, NSURLErrorCancelled):
                    guard let localFileLocation = assets[id]?
                        .getURLAsset()?
                        .url
                    else {
                        return
                    }

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
                let bookmark = try downloadURL.bookmarkData()
                asset.bookmark = bookmark
                asset.status = HLSAsset.DownloadState.FINISHED
                asset.size = getHLSFileSize(asset.getURLAsset()!.url.path)
                saveAssetData(asset: asset)
                checkQueue()
            } catch {
                print("Failed to save downloaded asset: \(error)")
            }
        }
    }

    // MARK: Location determined
    
    /// Method called when the an aggregate download task determines the location this asset will be downloaded to.
    public func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
                    willDownloadTo location: URL) {

        /*
        This delegate callback should only be used to save the location URL
        somewhere in your application. Any additional work should be done in
        `URLSessionTaskDelegate.urlSession(_:task:didCompleteWithError:)`.
        */
        
        guard let id = aggregateAssetDownloadTask.taskDescription else { return }
        downloadUrls[id] = location
        
        do {
            let bookmark = try location.bookmarkData()
            guard let asset = assets[id] else { return }
            asset.bookmark = bookmark
            saveAssetData(asset: asset)
        } catch {
            print("Failed to save asset bookmark: \(error)")
        }
    }

    /// Method called when a child AVAssetDownloadTask completes.
    public func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
                    didCompleteFor mediaSelection: AVMediaSelection) {
        /*
         This delegate callback provides an AVMediaSelection object which is now fully available for
         offline use. You can perform any additional processing with the object here.
         */
        
        aggregateAssetDownloadTask.resume()
    }

    // MARK: Progress updated
    
    /// Method to adopt to subscribe to progress updates of an AVAggregateAssetDownloadTask.
    public func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
                    didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                    timeRangeExpectedToLoad: CMTimeRange, for mediaSelection: AVMediaSelection) {

        guard
            let id = aggregateAssetDownloadTask.taskDescription,
            let asset = assets[id]
        else {
            return
        }

        var percentComplete = 0.0
        for value in loadedTimeRanges {
            let loadedTimeRange: CMTimeRange = value.timeRangeValue
            percentComplete +=
                loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds
        }
        asset.progress = percentComplete
        let filePath = asset.getURLAsset()?.url.path
        if (filePath != nil) {
            asset.size = getHLSFileSize(filePath!)
        }
        saveAssetData(asset: asset)
    }
    
    // MARK: Error
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("Something went wrong: \(String(describing: error))")
    }
}

