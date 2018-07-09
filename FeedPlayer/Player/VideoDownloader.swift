//
//  VideoDownloader.swift
//  Allmuze_V2
//
//  Created by Muhammad Abed Ekrazek on 10/16/17.
//  Copyright © 2017 Allmuze Inc. All rights reserved.
//

import UIKit

protocol VideoDownloaderDataSource : class
{
    func videoDownloaderGetCurrentPlayingObjectId() -> String?
    func videoDownloaderDataSourceGetCurrentTime() -> Double?
}


protocol VideoDownloaderDelegate : class
{
    func videoDownloaderDidReceiveNewDataFor(videoCachedFile : VideoCachedFile)
}

protocol CongistionControllerDelegate : class
{
    func congistionControllerDidChangeMode()
    func congistionControllerDelegateResendCurrentPlayingVideo()
}






class VideoCachedFile : NSObject , NSCoding
{
    override init()
    {
        super.init()
    }
    
    let K_BYTES_PER_MOVE = 200 * 1024
    
    var cached : Bool = false
    var size : Int64?
    var data = NSMutableData()
    var dataTask : URLSessionDataTask?
    var response : URLResponse?
    var id : String!
    var url : URL!
    var duration : CLong!
    var tempData = NSMutableData() // save here a portion of data and when it arrives to a certian amount move it to data
    //    var shouldSaveToDiskWhenFinishDOwnloadingPortion = false
    var prefetechDownloadPortion : Float
    {
        get
        {
            return min( ( Float(3) / Float(self.duration) ) , 1)
        }
    }
    
    
    required init?(coder aDecoder: NSCoder)
    {
        
        if let _size = aDecoder.decodeObject(forKey: "size") as? Int64
        {
            self.size = _size
        }
        if let _data = aDecoder.decodeObject(forKey: "data") as? NSMutableData
        {
            self.data = _data
        }
        if let _response = aDecoder.decodeObject(forKey: "response") as? URLResponse
        {
            self.response = _response
        }
        if let _id = aDecoder.decodeObject(forKey: "id") as? String
        {
            self.id = _id
        }
        if let _url = aDecoder.decodeObject(forKey: "url") as? URL
        {
            self.url = _url
        }
        if let _duration = aDecoder.decodeObject(forKey: "duration") as? CLong
        {
            self.duration = _duration
        }
        
    }
    
    func encode(with aCoder: NSCoder)
    {
        aCoder.encode(self.size, forKey: "size")
        
        aCoder.encode(self.data, forKey: "data")
        
        aCoder.encode(self.response, forKey: "response")
        
        
        aCoder.encode(self.id, forKey: "id")
        
        aCoder.encode(self.url, forKey: "url")
        
        aCoder.encode(self.duration, forKey: "duration")
    }
    
    
    func addData(data : Data)
    {
        self.tempData.append(data)
        if let _size = self.size
        {
            if self.tempData.length >= self.K_BYTES_PER_MOVE || self.tempData.length + self.data.length >= _size
            {
                self.data.append(self.tempData as Data)
                self.tempData = NSMutableData()
            }
        }
        else
        {
            //fatalError("appending to object swith no size : ")
            
            print(classRef: self, txt: "not such file!", type: .error)
        }
    }
    
    func flushTmpData()
    {
        self.data.append(self.tempData as Data)
        self.tempData = NSMutableData()
    }
    
}






//its not a singleton any more!!! be advised !!

class VideoDownloader : NSObject , URLSessionDataDelegate, NSCacheDelegate , CongistionControllerDelegate
{
    struct DownloadFile
    {
        var id = ""
        var url = ""
        var duration : CLong = 0
    }
    
    
    /////////////////////////////////////////////////////////////////////////////////////
    class CongistionController
    {
        enum Mode : String
        {
            case normal = "normal"  , currentPlayingWins = "currentPlayingWins"
        }
        private(set) var mode = Mode.normal
        {
            didSet
            {
                self.deleagate?.congistionControllerDidChangeMode()
            }
        }
        
        weak var deleagate : CongistionControllerDelegate?
        
        /*
         value between {0 , 1]
         
         checkCurrentPlayingItemForCongistionControl return value  must be bigger than congistionControlValue in the normal mode
         or else it will be in currentPlayingWins
         
         after we find out that the current playing video needs to be downloaded alone
         we make this bigger so that movin g back to normal would take longer (took this idea from the X^3 function of tcp protocol)
         
         */
        private(set) var congistionControlValue : Double
        private let CONGISTION_MIN_VALUE = 0.1
        private var congistionIncreaseCounter = Double(0)
        
        //counts the number of periods (period related to the call rate of the checking timer) that the current playing object didn't proceed
        private var notMovingCounter = 0
        private var NOT_MOVING_CNT_MAX = 10
        private var lastPercentage = Float(0)
        
        private var options : FeedPlayer.Options
        
        init(options : FeedPlayer.Options)
        {
            self.options = options
            self.congistionControlValue = self.CONGISTION_MIN_VALUE
        }
        
        func checkAndUpdateCurrentPlayingItemForCongistionControl(downloadProgress : Double , playingProgress : Double , duration : Double )
        {
            let checkValue = downloadProgress - ( (playingProgress == 0 ? duration : playingProgress) /* if the progress unknown or zero checkValue would be maximum  */  / duration)

            if self.options.debug
            {
                print(classRef: self, txt: "Congestions value : \(self.congistionControlValue)", type: .info)
                print(classRef: self, txt: "downloadProgress : \(downloadProgress) , playingProgress : \(playingProgress) , duration : \(duration)", type: .info)
                print(classRef: self, txt: "checkValue : \(checkValue)", type: .info)

            }
            
            if  checkValue > self.congistionControlValue
            {
                self.mode = .normal
                self.congistionIncreaseCounter = 0
                self.resetControlVale()
            }
            else
            {
                self.mode = .currentPlayingWins
                self.congistionControlValue = self.ahmedsFunction(x: self.congistionControlValue)
                self.congistionIncreaseCounter += 1
            }
        }
        
        func resetControlVale()
        {
            self.congistionControlValue = self.CONGISTION_MIN_VALUE
        }
        
        func resetAllCongistionValues()
        {
            self.resetControlVale()
            self.congistionIncreaseCounter = 0
            self.mode = .normal
        }
        
        //By : Ahmad Hamdan
        private func ahmedsFunction(x : Double) -> Double
        {
            return 1.0 - ( 0.9 / ( 1.0 + x ) )
        }
        
        func checkLastPercentageForCurrentPlayingObject(newPrecentage : Float)
        {
            if newPrecentage == self.lastPercentage // didn't move
            {
                self.notMovingCounter += 1
                
                if notMovingCounter >= self.NOT_MOVING_CNT_MAX
                {
                    self.deleagate?.congistionControllerDelegateResendCurrentPlayingVideo()
                    self.notMovingCounter = 0
                    self.lastPercentage = 0
                }
            }
            else
            {
                self.lastPercentage = newPrecentage
                self.notMovingCounter = 0
            }
            
            if self.options.debug
            {
                print(classRef: self, txt: "not proceding counter = \(self.notMovingCounter)", type: .info)
            }
        }
        
        func resetNotProceedingData()
        {
            self.notMovingCounter = 0
            self.lastPercentage = 0
        }
    }
    
    /////////////////////////////////////////////////////////////////////////////////////
    
    private var resendLowPrioritySemaphore = DispatchSemaphore(value: 1) // in order to synchronize calls for resendLowPriority function
    
    weak var dataSource : VideoDownloaderDataSource?
    weak var delegate : VideoDownloaderDelegate?
    
    private var congistionController : CongistionController
    private var lowPriorityVideoCachedFiles = [VideoCachedFile]()
    
    
    
    
    //    static let sharedInstance = VideoDownloader()
    
    private var idVideoCache = NSCache<NSString, VideoCachedFile>() //cache from record id to VideoCachedFile
    private var videosInCacheArr = [NSString]() //array of ids in the cache
    private var session : URLSession!
    private var taskIdIdDic = [Int : String]() // [taskId : ID]
    
    private var currentWorkingTasks = [URLSessionDataTask]()
    {
        didSet
        {
            if self.options.debug
            {
                print(classRef: self, txt: "data tasks count : \(self.currentWorkingTasks.count)", type: .info)
            }
        }
    }
    
    private var options : FeedPlayer.Options
    
    private var diskDataCache : DiskDataCache
    
    init(options : FeedPlayer.Options)
    {
        self.options = options
        self.congistionController = CongistionController(options: options)
        self.diskDataCache = DiskDataCache(options: options)
        super.init()
        self.idVideoCache.delegate = self
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        self.session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        
        self.congistionController.deleagate = self
        
    }
    
    func congistionControllerDidChangeMode()
    {
        if self.congistionController.mode == .normal
        {
            if self.options.debug
            {
                print(classRef: self, txt: "congistion control value changed to normalll", type: .info)
            }
            if self.lowPriorityVideoCachedFiles.count > 0
            {
                if self.options.debug
                {
                    print(classRef: self, txt: "MODE CHANGED : resending stuff ", type: .info)
                }
                self.resendLowPriorityFiles()
            }
        }
        else
        {
            if self.options.debug
            {
                print(classRef: self, txt: "congistion control value changed to current player wins ", type: .info)
            }
        }
    }
    
    func congistionControllerDelegateResendCurrentPlayingVideo()
    {
        
    }
    
    
    
    func downloadObject(object : DownloadFile)
    {
        let _cachedFile = self.idVideoCache.object(forKey: object.id as NSString)
        
        if _cachedFile == nil // not in ram
        {
            if let _diskCachedFile = self.diskDataCache.getFileFromDisk(id: object.id) // on disk
            {
                if let _size = _diskCachedFile.size
                {
                    let dataLength = _diskCachedFile.data.length
                    if dataLength < Int(_size)
                    {
                        let dataTask = self.sendRangeDownloadRequestFor(videoCachedFile: _diskCachedFile)
                        self.currentWorkingTasks.append(dataTask)
                        _diskCachedFile.dataTask = dataTask
                        self.taskIdIdDic.removeValue(forKey: _diskCachedFile.dataTask?.taskIdentifier ?? -1)
                        self.taskIdIdDic[dataTask.taskIdentifier] = object.id
                    }
                    self.idVideoCache.setObject(_diskCachedFile, forKey: object.id as NSString)
                    self.videosInCacheArr.appendIfNotExist( object.id as NSString)
                }
                else
                {
                    if self.options.debug
                    {
                        print(classRef: self, txt: "cached file with no size ", type: .info)
                    }
                }
            }
            else // neither on disk nor on ram
            {
                if let _url = URL(string: object.url)
                {
                    let request = URLRequest(url: _url)
                    let dataTask = self.session.dataTask(with: request)
                    self.currentWorkingTasks.append(dataTask)
                    
                    dataTask.resume()
                    
                    dataTask.priority = 0.35
                    
                    let videoCachedFile = VideoCachedFile()
                    videoCachedFile.url = _url
                    videoCachedFile.dataTask = dataTask
                    videoCachedFile.id = object.id
                    videoCachedFile.duration = object.duration
                    self.idVideoCache.setObject(videoCachedFile, forKey: object.id as NSString)
                    self.videosInCacheArr.appendIfNotExist( object.id as NSString)
                    self.taskIdIdDic[dataTask.taskIdentifier] = object.id
                }
            }
        }
    }
    
    
    
    func prepareFileToPlay(fileId : String)
    {
        if let _cachedFile = self.getVideoCachedFileWithId(id: fileId)
        {
            if let _dataTask = _cachedFile.dataTask
            {
                if _dataTask.state != .completed && _dataTask.state != .running // an error occured or its canceled dur to prefetch portion limitation
                {
                    if let _size = _cachedFile.size
                    {
                        let dataLength = _cachedFile.data.length
                        if dataLength < Int(_size) //
                        {
                            let dataTask = self.sendRangeDownloadRequestFor(videoCachedFile: _cachedFile)
                            self.currentWorkingTasks.append(dataTask)
                            self.taskIdIdDic.removeValue(forKey: _cachedFile.dataTask?.taskIdentifier ?? -1)
                            
                            _cachedFile.dataTask = dataTask
                            self.taskIdIdDic[dataTask.taskIdentifier] = _cachedFile.id
                        }
                    }
                    else // the task is running or completed but there's no size
                    {
                        self.resendDownloadRequestFor(cachedFile: _cachedFile)
                    }
                }
                else
                {
                    if _dataTask.state == .completed
                    {
                        if let _size = _cachedFile.size
                        {
                            if Int(_cachedFile.data.length) < _size  // the process is completed , but the size isn;t enought
                            {
                                self.taskIdIdDic.removeValue(forKey: _cachedFile.dataTask?.taskIdentifier ?? -1)
                                
                                let dataTask = self.sendRangeDownloadRequestFor(videoCachedFile: _cachedFile)
                                
                                self.currentWorkingTasks.append(dataTask)
                                _cachedFile.dataTask = dataTask
                                self.taskIdIdDic[dataTask.taskIdentifier] = _cachedFile.id
                                
                                self.videosInCacheArr.appendIfNotExist( _cachedFile.id as NSString)
                                
                            }
                        }
                        else
                        {
                            self.taskIdIdDic.removeValue(forKey: _cachedFile.dataTask?.taskIdentifier ?? -1)
                            let request = URLRequest(url: _cachedFile.url)
                            let dataTask = self.session.dataTask(with: request)
                            self.currentWorkingTasks.append(dataTask)
                            
                            _cachedFile.dataTask = dataTask
                            self.taskIdIdDic[dataTask.taskIdentifier] = _cachedFile.id
                            self.videosInCacheArr.appendIfNotExist( _cachedFile.id as NSString)
                        }
                    }
                    if self.options.debug
                    {
                        print(classRef: self, txt: "task state is : \(_dataTask.state.rawValue)", type: .info)
                    }
                }
            }
        }
    }
    
    
    
    private func resendDownloadRequestFor(cachedFile : VideoCachedFile)
    {
        cachedFile.dataTask?.cancel()
        
        self.taskIdIdDic.removeValue(forKey: cachedFile.dataTask?.taskIdentifier ?? -1)
        
        let request = URLRequest(url: cachedFile.url)
        let dataTask = self.session.dataTask(with: request)
        self.deleteDataTaskFormCurrent(dataTask: dataTask)
        self.currentWorkingTasks.append(dataTask)
        
        self.idVideoCache.setObject(cachedFile, forKey: cachedFile.id as NSString)
        self.videosInCacheArr.appendIfNotExist( cachedFile.id as NSString)
        self.taskIdIdDic[dataTask.taskIdentifier] = cachedFile.id
    }
    
    ////// private functions /////
    
    private func sendRangeDownloadRequestFor(videoCachedFile : VideoCachedFile) -> URLSessionDataTask
    {
        var request = URLRequest(url: videoCachedFile.url)
        request.setValue("bytes=\(videoCachedFile.data.length)-", forHTTPHeaderField: "Range")
        let dataTask = self.session.dataTask(with: request)
        dataTask.resume()
        
        return dataTask
    }
    
    
    private func saveVideoCachedFileToDisk(videoCachedFile : VideoCachedFile)
    {
        self.diskDataCache.saveToDisk(videoCachedFile: videoCachedFile)
    }
    
    
    
    ////// private functions /////
    
    
    //Url session data task
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data)
    {
        if let _objectId = self.taskIdIdDic[dataTask.taskIdentifier]
        {
            if let _cachedFile = self.idVideoCache.object(forKey: _objectId as NSString)
            {
                _cachedFile.addData(data: data)
                self.delegate?.videoDownloaderDidReceiveNewDataFor(videoCachedFile: _cachedFile)
                
                if _cachedFile.size == nil
                {
                    dataTask.cancel()
                    self.resendDownloadRequestFor(cachedFile: _cachedFile)
                }
                let progress = Float(_cachedFile.data.length) / Float(_cachedFile.size!)
                //                print(classRef: self, txt: "progress : \(progress) , url : \(_cachedFile.url.absoluteString)", type: .info)
                print(classRef: self, txt: "progress : \(progress) , id : \(dataTask.taskIdentifier)", type: .info)
                
                self.givePriorityOrSuspend(videoCachedFile: _cachedFile, dataTask: dataTask, progress: progress)
            }
            else
            {
                if self.options.debug
                {
                    print(classRef: self, txt: "no such file", type: .error)
                }
            }
        }
        else
        {
            if self.options.debug
            {
                print(classRef: self, txt: "no object id with this task id ", type: .error)
            }
        }
    }
    
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?)
    {
        if self.options.debug
        {
            print(classRef: self, txt: "did become invalid with error : \(error)", type: .error)
        }
    }
    
    
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask)
    {
        if self.options.debug
        {
            print(classRef: self, txt: "taskIsWaitingForConnectivity data task id : \(task.taskIdentifier)", type: .info)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        if self.options.debug
        {
            print(classRef: self, txt: "didCompleteWithError : error ? : \(error)", type: .info)
        }
    }
    
    
    
    
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)
    {
        if let objectId = self.taskIdIdDic[dataTask.taskIdentifier]
        {
            if let videoCachedFile = self.idVideoCache.object(forKey: objectId as NSString)
            {
                
                if let _httpResponse = response as? HTTPURLResponse
                {
                    if (_httpResponse.statusCode != 200 && _httpResponse.statusCode != 206)
                    {
                        videoCachedFile.size = nil
                        videoCachedFile.response = nil
                        completionHandler(.cancel)
                        self.deleteDataTaskFormCurrent(dataTask: dataTask)
                        return
                    }
                }
                
                completionHandler(.allow)
                if !videoCachedFile.cached
                {
                    if videoCachedFile.size == nil //its a range request
                    {
                        videoCachedFile.response = response
                        videoCachedFile.size = response.expectedContentLength
                    }
                }
                else
                {
                    if self.options.debug
                    {
                        print(classRef: self, txt: "cached file so w'ere not changing the response because it has a different expected content length than the original", type: .info)
                    }
                }
            }
        }
    }
    
    
    func getVideoCachedFileWithId(id : String) -> VideoCachedFile?
    {
        return self.idVideoCache.object(forKey: id as NSString)
    }
    
    
    
    func saveVideosToDisk()
    {
        for id in self.videosInCacheArr
        {
            if let obj = self.idVideoCache.object(forKey: id)
            {
                if let _dataTask = obj.dataTask
                {
                    _dataTask.cancel()
                    obj.flushTmpData()
                    self.saveVideoCachedFileToDisk(videoCachedFile: obj)
                }
            }
        }
        
    }
    
    
    
    
    
    //other heloing functions
    
    private func deleteDataTaskFormCurrent(dataTask : URLSessionDataTask)
    {
        if let _index = self.currentWorkingTasks.index(of: dataTask)
        {
            self.currentWorkingTasks.remove(at: _index)
        }
    }
    
    
    
    private func givePriorityOrSuspend(videoCachedFile : VideoCachedFile , dataTask : URLSessionDataTask , progress : Float)
    {
        if self.options.debug
        {
            print(classRef: self, txt: "************************************************************************\n", type: .info)
        }
        
        let currebtPlayingId = self.dataSource?.videoDownloaderGetCurrentPlayingObjectId() ?? ""
        if let _currentPlayingFile = self.getVideoCachedFileWithId(id: currebtPlayingId) // check if need to change modes , by checking the current playing item situation
        {
            let duration = Double(_currentPlayingFile.duration)
            var progress = Double(0)
            if let _size = _currentPlayingFile.size
            {
                progress = Double(_currentPlayingFile.data.length) / Double(_size)
            }
            
            if progress >= 0.95
            {
                self.congistionController.resetControlVale()
                self.congistionController.resetAllCongistionValues()
            }
            else
            {
                
                self.congistionController.checkAndUpdateCurrentPlayingItemForCongistionControl(downloadProgress: progress,
                                                                                               playingProgress: self.dataSource?.videoDownloaderDataSourceGetCurrentTime() ?? duration ,
                                                                                               duration: duration)
                if self.options.debug
                {
                    print(classRef: self, txt: "\ncurrent playing id : \(dataTask.taskIdentifier)\nprogress : \(progress)\nMode after change : \(self.congistionController.mode.rawValue)", type: .info)
                }
            }
        }
        
        if videoCachedFile.id == currebtPlayingId
        {
            dataTask.priority = 1.0
        }
        else //not the current playing data
        {
            if self.congistionController.mode == .currentPlayingWins
            {
                if self.options.debug
                {
                    print(classRef: self, txt: "data task : \(dataTask.taskIdentifier) suspended due to currentPlayingWins mode", type: .info)
                }
                dataTask.cancel()
                videoCachedFile.flushTmpData()
                self.lowPriorityVideoCachedFiles.append(videoCachedFile)
            }
            else // normal mode
            {
                if self.lowPriorityVideoCachedFiles.count > 0
                {
                    self.resendLowPriorityFiles()
                }
                if progress >= videoCachedFile.prefetechDownloadPortion && videoCachedFile.duration > 5
                {
                    if self.options.debug
                    {
                        print(classRef: self, txt: "Setting : \(dataTask.taskIdentifier) : cancel due to  ", type: .info)
                    }
                    dataTask.cancel()
                    self.deleteDataTaskFormCurrent(dataTask: dataTask)
                    videoCachedFile.flushTmpData()
                    self.saveVideoCachedFileToDisk(videoCachedFile: videoCachedFile)
                }
                else
                {
                    if self.options.debug
                    {
                        print(classRef: self, txt: "Setting : \(dataTask.taskIdentifier) : default", type: .info)
                    }
                    dataTask.priority = URLSessionTask.lowPriority
                }
            }
        }
        
        if self.options.debug
        {
            print(classRef: self, txt: "************************************************************************\n", type: .info)
        }
    }
    
    private func resendLowPriorityFiles()
    {
        self.resendLowPrioritySemaphore.wait()
        
        if self.options.debug
        {
            print(classRef: self, txt: "RESENDING Low priority files", type: .info)
        }
        for file in self.lowPriorityVideoCachedFiles
        {
            self.taskIdIdDic.removeValue(forKey: file.dataTask?.taskIdentifier ?? -1)
            
            let dataTask = self.sendRangeDownloadRequestFor(videoCachedFile: file)
            self.currentWorkingTasks.append(dataTask)
            file.dataTask = dataTask
            self.taskIdIdDic[dataTask.taskIdentifier] = file.id
            self.videosInCacheArr.appendIfNotExist( file.id as NSString)
        }
        self.lowPriorityVideoCachedFiles.removeAll()
        
        self.resendLowPrioritySemaphore.signal()
    }
    
    
    //MARK: nscache delegate
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any)
    {
        if let cachedFile = obj as? VideoCachedFile
        {
            cachedFile.dataTask?.cancel()
            if self.options.debug
            {
                print("video will be evicted from cache \(cachedFile.id)")
            }
            self.saveVideoCachedFileToDisk(videoCachedFile: cachedFile)
            if let index = self.videosInCacheArr.index(of: cachedFile.id as NSString)
            {
                self.videosInCacheArr.remove(at: index)
            }
        }
    }

    
    
}























