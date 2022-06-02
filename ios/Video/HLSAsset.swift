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
    let id: String
    
    /// HLS stream m3u8 url
    let hlsURL: String
    
    /// Download progress percentage
    var progress: Double = 0
    
    /// Asset download status
    var status: HLSAsset.DownloadState
    
    /// Asset size in bytes
    var size: Double = 0

    
    init(
         id: String,
         hlsURL: String,
         urlAsset: AVURLAsset,
         status: HLSAsset.DownloadState = HLSAsset.DownloadState.IDLE,
         size: Double = 0.0
    ) {
        self.urlAsset = urlAsset
        self.id = id
        self.hlsURL = hlsURL
        self.status = status
        self.size = size
        
        if (status == HLSAsset.DownloadState.FINISHED) {
            self.progress = 1
        }
    }
    
    public func formattedDataJS() -> NSMutableDictionary {
        let data: NSMutableDictionary = [:]
       
        data["id"] = id
        data["hlsUrl"] = hlsURL
        data["progress"] = progress
        data["status"] = status.rawValue
        data["size"] = size
        
        return data
    }

    public func encodeAssetDataToString() -> String {
        return id + HLSAsset.stringSeparator + hlsURL
    }

    public static func decodeAssetDataFromString(_ dataString: String) -> (id: String, hlsURL: String) {
        let arr = dataString.components(separatedBy: HLSAsset.stringSeparator)
        let id = arr[0]
        let hlsURL = arr[1]
        return (id, hlsURL)
    }
}

/// Extends `Asset` to conform to the `Equatable` protocol.
extension HLSAsset: Equatable {
    public static func ==(lhs: HLSAsset, rhs: HLSAsset) -> Bool {
        return (lhs.id == rhs.id) 
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
