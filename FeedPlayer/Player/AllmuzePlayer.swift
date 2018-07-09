//
//  AllmuzePlayer.swift
//  FirstCocaPods
//
//  Created by Muhammad Abed Ekrazek on 7/8/18.
//  Copyright © 2018 Muhammad Abed Ekrazek. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer

enum AllmuzePlayerState : Int
{
    case playing = 0 , buffering, paused , error
}

protocol AllmuzePlayerDelegate : class
{
    func allmuzePlayerDelegateStateChanged(_ player : AllmuzePlayer, currentState : AllmuzePlayerState)
    func allmuzePlayerDelegateFinishedPlaying(_ player : AllmuzePlayer, currentState : AllmuzePlayerState)
}



class AllmuzePlayer : AVPlayer
{
    var tag : Int = -1
    
    weak var delegate : AllmuzePlayerDelegate?
    
    var playerObserver = false
    
    var state : AllmuzePlayerState = .paused
    
    var duration : Double?
    {
        get
        {
            if let currItem = self.currentItem
            {
                return Double(CMTimeGetSeconds(currItem.asset.duration))
            }
            return nil
        }
    }
    
    var currentTime : Double?
    {
        get
        {
            return CMTimeGetSeconds(self.currentTime())
        }
    }
    
    
    override init()
    {
        super.init()
    }
    
    override init(url URL: URL)
    {
        super.init(url: URL)
    }
    
    
    override init(playerItem item: AVPlayerItem?)
    {
        super.init(playerItem: item)
        
        if #available(iOS 10.0, *)
        {
            self.automaticallyWaitsToMinimizeStalling = false
        }
        self.prepareItem(item: item!)
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
        
        self.removeObservers()
    }
    
    func prepareItem(item : AVPlayerItem)
    {
        if !self.playerObserver
        {
            NotificationCenter.default.addObserver(self, selector: #selector(self.playerFinishedPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)
            NotificationCenter.default.addObserver(self, selector: #selector(self.playInterrupt), name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
            NotificationCenter.default.addObserver(self, selector: #selector(playbackStalledHandler), name:NSNotification.Name.AVPlayerItemPlaybackStalled, object: self)
            
            self.addObserver(self, forKeyPath: "status", options: .new, context: nil)
            item.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
            item.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
            item.addObserver(self, forKeyPath: "playbackBufferFull", options: .new, context: nil)
            self.playerObserver = true
        }
    }
    
    
    @objc func playbackStalledHandler()
    {
        self.delegate?.allmuzePlayerDelegateStateChanged(self, currentState: AllmuzePlayerState.buffering)
    }
    
    
    override func play()
    {
        if let _currnItem = self.currentItem
        {
            self.prepareItem(item: _currnItem)
        }
        super.play()
    }
    
    override func pause()
    {
        
        super.pause()
        
        self.state = .paused
        self.delegate?.allmuzePlayerDelegateStateChanged(self, currentState: .paused)
    }
    
    func resume()
    {
       
        super.play()
        
        self.state = .playing
        self.delegate?.allmuzePlayerDelegateStateChanged(self, currentState: .playing)
    }
    
    
    
    func stop()
    {
        DispatchQueue.main.async {
            super.pause()
            UIApplication.shared.endReceivingRemoteControlEvents()
            self.state = .paused
            self.delegate?.allmuzePlayerDelegateStateChanged(self, currentState: .paused)
        }
        
    }
    

    
    func seekTo(_ time : Double)
    {
        let _time = CMTimeMakeWithSeconds(time, 1000)
        
        if let _duration = self.duration
        {
            if time > _duration
            {
                self.state = .paused
                self.delegate?.allmuzePlayerDelegateFinishedPlaying(self, currentState: AllmuzePlayerState.paused)
                return
            }
            
        }
        
        self.seek(to: _time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
    }
    
    func seekToDirectly(time : Double)
    {
        let _time = CMTimeMakeWithSeconds(time, 1000)
        self.seek(to: _time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
    }
    
    func removeObservers()
    {
        if self.playerObserver
        {
            self.currentItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty")
            self.currentItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
            self.currentItem?.removeObserver(self, forKeyPath: "playbackBufferFull")
            
            NotificationCenter.default.removeObserver(self)
            
            self.removeObserver(self, forKeyPath: "status")
            self.playerObserver = false
        }
    }
    

    @objc func playerFinishedPlaying()
    {
        self.removeObservers()
        self.state = .paused
        self.delegate?.allmuzePlayerDelegateFinishedPlaying(self, currentState: .paused)
    }
    
    @objc func playInterrupt(_ notification: Foundation.Notification)
    {
        if notification.name == NSNotification.Name.AVAudioSessionInterruption && notification.userInfo != nil
        {
            var info = notification.userInfo!
            var intValue: UInt = 0
            
            (info[AVAudioSessionInterruptionTypeKey] as! NSValue).getValue(&intValue)
            
            if let type = AVAudioSessionInterruptionType(rawValue: intValue)
            {
                switch type
                {
                case .began:
                    if self.state == .playing
                    {
                        self.pause()
                        self.delegate?.allmuzePlayerDelegateFinishedPlaying(self, currentState: .paused)
                    }
                    break
                    
                case .ended:
                    break
                    
                }
            }
        }
    }
    
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        if let _ = object as? AVPlayerItem
        {
            if let player = object as? AVPlayer
            {
                if let _keyPath = keyPath, _keyPath == "status"
                {
                    if player.status == AVPlayerStatus.readyToPlay
                    {
                        if self.state == .paused
                        {
                            return
                        }
                    }
                    else if player.status == AVPlayerStatus.failed
                    {
                        
                        print(classRef: self, txt: "error player ", type: .error)
                        self.state = .error
                        self.delegate?.allmuzePlayerDelegateStateChanged(self, currentState: .error)
                    }
                }
            }
        }
        
    }
    

}

