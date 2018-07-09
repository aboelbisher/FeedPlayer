//
//  FeedPlayer.swift
//  Allmuze_V2
//
//  Created by Muhammad Abed Ekrazek on 9/14/17.
//  Copyright © 2017 Allmuze Inc. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

protocol FeedPlayerDataSource : class
{
    func feedPlayerObjectForId(id : String) -> VideoDownloader.DownloadFile?//feedPlayerUrlForId(_ objectId : String) -> String?
}

protocol FeedPlayerDelegate : class
{
    func allmuzePlayerDelegateFinishedPlaying(_ player: FeedPlayer, currentState: AllmuzePlayerState)
    func allmuzePlayerDelegateStateChanged(_ player: FeedPlayer, currentState: AllmuzePlayerState)
}


class FeedPlayer: NSObject , AllmuzePlayerDelegate , AVAssetResourceLoaderDelegate , VideoDownloaderDataSource , VideoDownloaderDelegate
{
    class Options
    {
        var maxDiskStorageSpace : UInt64
        var removeUnusedFileAge : TimeInterval
        
        var debug = false
        
        init(maxDiskStorageSpace : UInt64, removeUnusedFileAge : TimeInterval)
        {
            self.maxDiskStorageSpace = maxDiskStorageSpace
            self.removeUnusedFileAge = removeUnusedFileAge
        }
    }
    
    
    private var options : Options
    
    weak var delegate : FeedPlayerDelegate?
    weak var dataSource : FeedPlayerDataSource?
    
    private(set) var currentPlayingId : String?
    
    private(set) var currentPlayer : AllmuzePlayer?
    
    private var pendingRequests = Set<AVAssetResourceLoadingRequest>()
    
    
    private var videoDownloader : VideoDownloader
    
    
    private var timer: Timer?
    
    private var lastPlayerTimePeriodic = CMTime()
    
    var state = AllmuzePlayerState.paused
    
    private var pausedByUser = false // if pause() , stop()  called it will be true ,
    
    var duration : Double?
    {
        get
        {
            return self.currentPlayer?.duration
        }
    }
    
    var currentTime : Double?
    {
        get
        {
            return self.currentPlayer?.currentTime
        }
    }
    
    var rate: Float
    {
        get
        {
            if let _currentPlayer = self.currentPlayer
            {
                return _currentPlayer.rate
            }
            return 0
        }
    }
    
    init(options: Options)
    {
        self.options = options
        self.videoDownloader = VideoDownloader(options: options)

        super.init()
        
        
        self.videoDownloader.delegate = self
        self.videoDownloader.dataSource = self
    }
    
    func addObjectToPlay(signedUrl : String , forId id : String , duration : CLong)
    {
        let object = VideoDownloader.DownloadFile(id: id, url: signedUrl, duration: duration)
        self.videoDownloader.downloadObject(object: object)
    }
    
    
    func playFileWith(id : String)
    {
        self.currentPlayingId = id
        
        if let _ = self.videoDownloader.getVideoCachedFileWithId(id: id)
        {
            self.videoDownloader.prepareFileToPlay(fileId: id)
            let date = Int64(Date().timeIntervalSince1970 * 1000)
            let uniqueID = UUID().uuidString + "_" + String(date)
            let fakeUrlStr = "fake_scheme://host/video\(uniqueID).mp4"
            
            if let _fakeUrl = URL(string: fakeUrlStr)
            {
                self.pendingRequests.removeAll()
                let asset = AVURLAsset(url: _fakeUrl)
                asset.resourceLoader.setDelegate(self, queue: DispatchQueue.global(qos: .background))
                let item = AVPlayerItem(asset: asset)
                self.currentPlayer?.pause()
                self.currentPlayer?.delegate = nil
                self.currentPlayer = nil
                self.currentPlayer = AllmuzePlayer(playerItem: item)
                self.currentPlayer?.delegate = self
                
                
                self.removeTimer()
                self.iniTimer()
                                
                self.currentPlayer!.play()
                
                
                
                
                
            }
            
            self.processPendingRequests()
        }
        else
        {
            if self.options.debug
            {
                print(classRef: self, txt: "couldn't find the record in the downloader ", type: .info)
            }
            if let _record = self.dataSource?.feedPlayerObjectForId(id: id)
            {
                self.addObjectToPlay(signedUrl: _record.url,
                                     forId: _record.id,
                                     duration: _record.duration)
                self.playFileWith(id: id)
            }
        }
    }
    
    //    //MARK: ResourceLoadingDelegate
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest)
    {
        if self.options.debug
        {
            print(classRef: self, txt: "didCancel loadingRequest", type: .info)

        }
    }
    
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel authenticationChallenge: URLAuthenticationChallenge)
    {
        if self.options.debug
        {
            print(classRef: self, txt: "didCancel authenticationChallenge", type: .info)

        }
    }
    
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest) -> Bool
    {
        if self.options.debug
        {
            print(classRef: self, txt: "shouldWaitForRenewalOfRequestedResource", type: .info)
        }
        return true
    }
    
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForResponseTo authenticationChallenge: URLAuthenticationChallenge) -> Bool
    {
        if self.options.debug
        {
            print(classRef: self, txt: "shouldWaitForResponseTo authenticationChallenge", type: .info)

        }
        return true
    }
    
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool
    {
        if self.options.debug
        {
            print(classRef: self, txt: "shouldWaitForLoadingOfRequestedResource", type: .info)

        }
        self.pendingRequests.insert(loadingRequest)
        self.processPendingRequests()
        
        return true
    }
    
    
    private func processPendingRequests()
    {
        var remainRequests = Set<AVAssetResourceLoadingRequest>()
        
        for request in self.pendingRequests
        {
            self.fillInContentInformationRequest(request.contentInformationRequest)
            if self.haveEnoughDataToFulfillRequest(request.dataRequest!)
            {
                request.finishLoading()
            }
            else
            {
                remainRequests.insert(request)
            }
        }
        self.pendingRequests = remainRequests
    }
    
    
    private func fillInContentInformationRequest(_ contentInformationRequest: AVAssetResourceLoadingContentInformationRequest?)
    {
        if let _videoCachedFile = self.videoDownloader.getVideoCachedFileWithId(id: self.currentPlayingId!)
        {
            if let responseUnwrapped = _videoCachedFile.response
            {
                contentInformationRequest?.contentType = responseUnwrapped.mimeType
                contentInformationRequest?.contentLength = responseUnwrapped.expectedContentLength
                contentInformationRequest?.isByteRangeAccessSupported = true
            }
            else
            {
                if self.options.debug
                {
                    print(classRef: self, txt: "response is nulll ", type: .info)
                }
            }
        }
    }
    
    
    private func haveEnoughDataToFulfillRequest(_ dataRequest: AVAssetResourceLoadingDataRequest) -> Bool
    {
        if let _videoCachedFile = self.videoDownloader.getVideoCachedFileWithId(id: self.currentPlayingId!)
        {
            let data = _videoCachedFile.data
            let requestedOffset = Int(dataRequest.requestedOffset)
            let requestedLength = dataRequest.requestedLength
            let currentOffset = Int(dataRequest.currentOffset)
            
            if data.length < currentOffset
            {
                // no data to send
                return false
            }
            
            let bytesToRespond = min(data.length - currentOffset, requestedLength)
            
            if self.options.debug
            {
                print(classRef: self, txt: "data.length : \(data.length)", type: .info)
                print(classRef: self, txt: "requestedOffset : \(requestedOffset)", type: .info)
                print(classRef: self, txt: "requestedLength : \(requestedLength)", type: .info)
                print(classRef: self, txt: "currentOffset : \(currentOffset)", type: .info)
                print(classRef: self, txt: "bytesToRespond : \(bytesToRespond)", type: .info)

            }
            
            
            let dataToRespond = data.subdata(with: NSRange(location: currentOffset, length: bytesToRespond ))
            dataRequest.respond(with: dataToRespond)
            
            let value =  data.length >= requestedLength + requestedOffset
            
            return value
        }
        
        return false
    }
    
    
    
    
    
    
    ///////////////////////// downloader delegate
    
    func videoDownloaderGetCurrentPlayingObjectId() -> String?
    {
        return self.currentPlayingId
    }
    
    func videoDownloaderDidReceiveNewDataFor(videoCachedFile: VideoCachedFile)
    {
        if let _currId = self.currentPlayingId
        {
            if videoCachedFile.id == _currId
            {
                self.processPendingRequests()
                
                if !self.pausedByUser
                {
                    self.play()
                }
            }
        }
    }
    
    func videoDownloaderDataSourceGetCurrentTime() -> Double?
    {
        return self.currentTime
    }
    
    /////////// public functions
    
    func allmuzePlayerDelegateFinishedPlaying(_ player: AllmuzePlayer, currentState: AllmuzePlayerState)
    {
        
        self.delegate?.allmuzePlayerDelegateFinishedPlaying(self, currentState: currentState)
    }
    
    
    func allmuzePlayerDelegateStateChanged(_ player: AllmuzePlayer, currentState: AllmuzePlayerState)
    {
        self.delegate?.allmuzePlayerDelegateStateChanged(self, currentState: currentState)
    }
    
    
    
    
    func play()
    {
        self.pausedByUser = false
        if let _currPlayer = self.currentPlayer
        {
            _currPlayer.play()
        }
        
    }
    
    
    
    func pause()
    {
        self.pausedByUser = true
        if let _currPlayer = self.currentPlayer
        {
            _currPlayer.pause()
        }
    }
    
    
    func resume()
    {
        self.pausedByUser = false
        if let _currPlayer = self.currentPlayer
        {
            _currPlayer.resume()
        }
    }
    
    
    func stop()
    {
        self.pausedByUser = true
        if let _currPlayer = self.currentPlayer
        {
            _currPlayer.stop()
        }
    }
    
    
    func seekTo(_ time : Double)
    {
        if let _currPlayer = self.currentPlayer
        {
            _currPlayer.seekTo(time)
        }
    }
    
    
    
    
    func saveFilesToDisk()
    {
        self.videoDownloader.saveVideosToDisk()
    }
    
    
    func removeTimer()
    {
        if let _timer = self.timer
        {
            _timer.invalidate()
            self.timer = nil
        }
    }
    
    func iniTimer()
    {
        self.timer = Timer.scheduledTimer(timeInterval: 0.5,
                                          target: self,
                                          selector: #selector(self.timerFunction(timer:)),
                                          userInfo: nil,
                                          repeats: true)
    }
    
    
    @objc func timerFunction(timer : Timer)
    {
        
        if let _player = self.currentPlayer
        {
            let currentTime = _player.currentTime()
            
            if _player.rate != 0 //playing or stalled
            {
                if self.lastPlayerTimePeriodic == currentTime // stalled
                {
                    if self.state != .buffering
                    {
                        self.state = .buffering
                        self.delegate?.allmuzePlayerDelegateStateChanged(self, currentState: .buffering)
                    }
                }
                else // playing
                {
                    
                    if self.state != .playing
                    {
                        self.state = .playing
                        self.delegate?.allmuzePlayerDelegateStateChanged(self, currentState: .playing)
                    }
                }
            }
            else
            {
                
                if self.state != .paused
                {
                    self.state = .paused
                    self.delegate?.allmuzePlayerDelegateStateChanged(self, currentState: .paused)
                }
                
            }
            
            self.lastPlayerTimePeriodic = currentTime
            
            
        }
        
        
    }
}
