//
//  DiskDataCache.swift
//  Allmuze_V2
//
//  Created by Muhammad Abed Ekrazek on 10/17/17.
//  Copyright © 2017 Allmuze Inc. All rights reserved.
//

import UIKit
import AVFoundation


class DiskDataCache: NSObject
{
    static let SAVED_IDS_KEY = "SavedIdsKey"
    
//    private var MAX_STORAGE_SPACE = UInt64(500 * 1024 * 1024)
    
    private var MUST_REMOVE_STORAGE : UInt64
    {
        get
        {
            return self.options.maxDiskStorageSpace / 10 // remove until reaching storage of MAX_STORAGE_SPACE - MUST_REMOVE_STORAGE
        }
    }
    
    
//    private var mustRemoveAge : TimeInterval = -7 * 24 * 60 * 60
    
    private var FILES_MUST_DELETE_LIMIT : TimeInterval
    {
        get
        {
            let now = Date()
            let date = now.addingTimeInterval(self.options.removeUnusedFileAge)
            return abs(date.timeIntervalSinceNow)
        }
    }
    
    
    private var options : FeedPlayer.Options
    
    
    
    
    init(options : FeedPlayer.Options)
    {
        self.options = options
        super.init()
//        self.MAX_STORAGE_SPACE = options.maxDiskStorageSpace
//        self.mustRemoveAge = options.removeUnusedFileAge
        
    }
    
    
    
    func saveToDisk(videoCachedFile : VideoCachedFile)
    {
        DispatchQueue.global(qos: .background).async {
            let data = NSKeyedArchiver.archivedData(withRootObject: videoCachedFile)
            if let _url = DiskDataCache.fileUrlFromId(id: videoCachedFile.id)
            {
                do
                {
                    
                    if FileManager.default.fileExists(atPath: _url.path)
                    {
                        try FileManager.default.removeItem(at: _url)
                    }
                }
                catch let err
                {
                    print(classRef: self, txt: "saving cached file to disk when removing prev : \(err)" , type: .error)
                }
                
                do
                {
                    try data.write(to: _url)
                    
                    var arr = [String]()
                    if let savedIds = Foundation.UserDefaults.standard.value(forKey: DiskDataCache.SAVED_IDS_KEY) as? [String]
                    {
                        arr = savedIds
                    }
                    
                    if arr.index(of: videoCachedFile.id) == nil
                    {
                        arr.append(videoCachedFile.id)
                    }
                    
                    
                    Foundation.UserDefaults.standard.setValue(arr, forKey: DiskDataCache.SAVED_IDS_KEY)
                    Foundation.UserDefaults.standard.synchronize()
                    print(classRef: self, txt: "filessaved succefully" , type: .info)
                }
                catch let err
                {
                    print(classRef: self, txt: "error saving file to disk :\(err)", type: .error)
                }
            }
            
        }
        
    }
    
    
    
    func getFileFromDisk(id : String) -> VideoCachedFile?
    {
        if let fileUrl = DiskDataCache.fileUrlFromId(id: id)
        {
            if let _file = NSKeyedUnarchiver.unarchiveObject(withFile: fileUrl.path) as? VideoCachedFile
            {
                _file.cached = true
                return _file
            }
        }
        return nil
    }
    
    
    
    func removeFileWithId(id : String)
    {
        if let _url = DiskDataCache.fileUrlFromId(id: id)
        {
            do
            {
                if FileManager.default.fileExists(atPath: _url.path)
                {
                    try FileManager.default.removeItem(at: _url)
                }
            }
            catch let err
            {
                print(classRef: self, txt: "removeFileWithId : \(err)", type: .error)
                
            }
        }
    }
    
    
    static func fileUrlFromId(id : String) -> URL?
    {
        if let baseUrl = getBaseDocument()
        {
            if let base64id = id.toBase64()
            {
                let finalUrl = baseUrl.appendingPathComponent("\(base64id)")
                return finalUrl
            }
        }
        return nil
    }
    
    
    //MARK: saved files must delete
    func checkVideoFilesToRemove()
    {
        DispatchQueue.global(qos: .background).async {
            
            var storage : UInt64 = 0 // only for files that age are < FILES_MUST_DELETE_LIMIT
            var storageFilesArr = [SotageFile]() // only for files that age are < FILES_MUST_DELETE_LIMIT
            var finalSavedIds = [String]()
            
            
            
            if let _savedIds = Foundation.UserDefaults.standard.value(forKey: DiskDataCache.SAVED_IDS_KEY) as? [String]
            {
                finalSavedIds = _savedIds
                for id in _savedIds
                {
                    if let _url = DiskDataCache.fileUrlFromId(id: id)
                    {
                        if let fileAge = getFileAge(path: _url.path)
                        {
                            if fileAge > self.FILES_MUST_DELETE_LIMIT
                            {
                                print(classRef: self, txt: "removing file id : \(id)", type: .info)
                                
                                do
                                {
                                    try FileManager.default.removeItem(at: _url)
                                }
                                catch let err
                                {
                                    print(classRef: self, txt: "\(err)", type: .error)
                                }
                            }
                            else
                            {
                                let fileSize = getFileSize(path: _url.path)
                                storage += fileSize
                                let storageFile = SotageFile(url: _url, age: fileAge , size : fileSize , id : id)
                                storageFilesArr.append(storageFile)
                            }
                        }
                    }
                }
                
                
                if storage > self.options.maxDiskStorageSpace
                {
                    let mustRemoveStorage = (storage - self.options.maxDiskStorageSpace) + self.MUST_REMOVE_STORAGE
                    
                    
                    let sortedArr = storageFilesArr.sorted(by: { (file1, file2) -> Bool in
                        return file1.age > file2.age
                    })
                    
                    var removedStorage : UInt64 = 0
                    var urlsToRemove = [URL]()
                    
                    for file in sortedArr
                    {
                        removedStorage += file.size
                        urlsToRemove.append(file.url)
                        if let indexOf = finalSavedIds.index(of: file.id)
                        {
                            finalSavedIds.remove(at: indexOf)
                        }
                        
                        if removedStorage > mustRemoveStorage
                        {
                            continue
                        }
                    }
                    
                    for url in urlsToRemove
                    {
                        do
                        {
                            try FileManager.default.removeItem(at: url)
                        }
                        catch let err
                        {
                            print(classRef: self, txt: "removing file while cleaning : \(err)", type: .error)
                            
                        }
                    }
                    
                    Foundation.UserDefaults.standard.setValue(finalSavedIds, forKey: DiskDataCache.SAVED_IDS_KEY)
                    Foundation.UserDefaults.standard.synchronize()
                }
                
            }
        }
        
    }
    
    
    
}

struct SotageFile
{
    var url : URL!
    var age : TimeInterval!
    var size : UInt64!
    var id : String
}


