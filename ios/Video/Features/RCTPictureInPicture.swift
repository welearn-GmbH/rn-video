import AVFoundation
import AVKit
import MediaAccessibility
import React
import Foundation

#if TARGET_OS_IOS
class RCTPictureInPicture: NSObject, AVPictureInPictureControllerDelegate {
    private var _videoController: RCTVideo?
    private var _onRestoreUserInterfaceForPictureInPictureStop: RCTDirectEventBlock?
    private var _restoreUserInterfaceForPIPStopCompletionHandler:((Bool) -> Void)? = nil
    private var _pipController:AVPictureInPictureController?
    private var _isActive:Bool = false
    
    init(_ videoController: RCTVideo) {
        _videoController = videoController
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        return
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {        
        _videoController?.onPictureInPictureStatusChanged?([ "isActive": NSNumber(value: true)])
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {        
        _videoController?.onPictureInPictureStatusChanged?([ "isActive": NSNumber(value: false)])
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        
        // Why do we care? This happens on every second toggle of PiP and crashes the app
        // assert(_restoreUserInterfaceForPIPStopCompletionHandler == nil, "restoreUserInterfaceForPIPStopCompletionHandler was not called after picture in picture was exited.")
        
        _videoController?.onRestoreUserInterfaceForPictureInPictureStop?([:])
              
        _restoreUserInterfaceForPIPStopCompletionHandler = completionHandler
    }
    
    func setRestoreUserInterfaceForPIPStopCompletionHandler(_ restore:Bool) {
        guard let _restoreUserInterfaceForPIPStopCompletionHandler = _restoreUserInterfaceForPIPStopCompletionHandler else { return }
        _restoreUserInterfaceForPIPStopCompletionHandler(restore)
        self._restoreUserInterfaceForPIPStopCompletionHandler = nil
    }
    
    func setupPipController(_ playerLayer: AVPlayerLayer?) {
        let isSupported = AVPictureInPictureController.isPictureInPictureSupported()
        guard playerLayer != nil && isSupported else { return }
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
        } catch {
           // nevermind
        }

        
        // Create new controller passing reference to the AVPlayerLayer
        _pipController = AVPictureInPictureController(playerLayer:playerLayer!)
        
        if #available(iOS 14.2, *) {
            _pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        } else {
            // nevermind
        }
        
        _pipController?.delegate = self
    }
    
    func setPictureInPicture(_ isActive:Bool) {
        if _isActive == isActive {
            return
        }
        _isActive = isActive
        
        guard let _pipController = _pipController else { return }
        
        if _isActive && !_pipController.isPictureInPictureActive {
            DispatchQueue.main.async(execute: {
                _pipController.startPictureInPicture()
            })
        } else if !_isActive && _pipController.isPictureInPictureActive {
            DispatchQueue.main.async(execute: {
                _pipController.stopPictureInPicture()
            })
        }
    }
}
#endif
