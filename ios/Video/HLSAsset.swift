/*
Abstract:
A simple class that holds information about an Asset.
*/

import AVFoundation

public class HLSAsset {
    static let stringSeparator = "***ayylmao***"
    /// The AVURLAsset corresponding to this Asset.
    var urlAsset: AVURLAsset
    
    /// Media asset name (for notifications)
    let name: String
    
    /// HLS stream m3u8 url
    let hlsURL: String
    
    /// Download progress percentage
    var progress: Double = 0
    
    /// Asset download status
    var status: HLSAsset.DownloadState

    
    init(
         name: String,
         hlsURL: String,
         urlAsset: AVURLAsset,
         status: HLSAsset.DownloadState = HLSAsset.DownloadState.IDLE
    ) {
        self.urlAsset = urlAsset
        self.name = name
        self.hlsURL = hlsURL
        self.status = status
        
        if (status == HLSAsset.DownloadState.FINISHED) {
            self.progress = 1
        }
    }
    
    public func formattedDataJS() -> NSMutableDictionary {
        let data: NSMutableDictionary = [:]
       
        data["name"] = name
        data["hlsUrl"] = hlsURL
        data["progress"] = progress
        data["status"] = status.rawValue
        
        return data
    }

    public func streamIdString() -> String {
        return name + HLSAsset.stringSeparator + hlsURL
    }

    public static func parseStreamIdString(streamId: String) -> (name: String, hlsURL: String) {
        let arr = streamId.components(separatedBy: HLSAsset.stringSeparator)
        let name = arr[0]
        let hlsURL = arr[1]
        return (name, hlsURL)
    }
}

/// Extends `Asset` to conform to the `Equatable` protocol.
extension HLSAsset: Equatable {
    public static func ==(lhs: HLSAsset, rhs: HLSAsset) -> Bool {
        return (lhs.name == rhs.name) && (lhs.hlsURL == rhs.hlsURL) && (lhs.urlAsset == rhs.urlAsset)
    }
}

/**
 Extends `Asset` to add a simple download state enumeration used by the sample
 to track the download states of Assets.
 */
extension HLSAsset {
    enum DownloadState: String {
        /// The asset has a download in progress.
        case PENDING
        
        /// The asset is downloaded and saved on diek.
        case FINISHED
        
        /// Download hasn't started yet
        case IDLE
        
        /// Download has failed
        case FAILED
    }
}

/**
 Extends `Asset` to define a number of values to use as keys in dictionary lookups.
 */
extension HLSAsset {
    struct Keys {
        /**
         Key for the Asset name, used for `AssetDownloadProgressNotification` and
         `AssetDownloadStateChangedNotification` Notifications as well as
         AssetListManager.
         */
        static let name = "AssetNameKey"

        /**
         Key for the Asset download percentage, used for
         `AssetDownloadProgressNotification` Notification.
         */
        static let percentDownloaded = "AssetPercentDownloadedKey"

        /**
         Key for the Asset download state, used for
         `AssetDownloadStateChangedNotification` Notification.
         */
        static let downloadState = "AssetDownloadStateKey"

        /**
         Key for the Asset download AVMediaSelection display Name, used for
         `AssetDownloadStateChangedNotification` Notification.
         */
        static let downloadSelectionDisplayName = "AssetDownloadSelectionDisplayNameKey"
    }
}
