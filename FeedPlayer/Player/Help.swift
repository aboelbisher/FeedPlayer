//
//  Help.swift
//  FirstCocaPods
//
//  Created by Muhammad Abed Ekrazek on 7/8/18.
//  Copyright © 2018 Muhammad Abed Ekrazek. All rights reserved.
//

import AVKit


enum PrintType : String
{
    case error = "ERROR" , test = "" , info = "INFO"
}

func print(classRef : Any , txt : String , type : PrintType)
{
    var strRef = String(describing : classRef)
    strRef = strRef.components(separatedBy: ":")[0]
    strRef = strRef.replacingOccurrences(of: "AllmuzeFinal.", with: "")
    print("\(strRef): \(type.rawValue): \(txt)")
}


extension Array where Element : Equatable
{
    
    mutating func appendIfNotExist(_ object : Element)
    {
        for obj in self
        {
            if obj == object
            {
                return
            }
        }
        self.append(object)
    }
    
}


extension String
{
    func toBase64() -> String?
    {
        guard let data = self.data(using: String.Encoding.utf8) else {
            return nil
        }
        
        return data.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
    }
}


func getBaseDocument() -> URL?
{
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    let documentDirectory = urls[0] as URL
    
    return documentDirectory
}

func getFileAge(path : String) -> TimeInterval?
{
    let fm = FileManager.default
    do
    {
        let attr = try fm.attributesOfItem(atPath: path)
        if let date = attr[FileAttributeKey.creationDate] as? Date
        {
            print("date : \(date)")
            return abs(date.timeIntervalSinceNow)
        }
    }
    catch let err
    {
        print("error getFileAge : \(err)")
    }
    return nil
}

func getFileSize(path : String) -> UInt64
{
    var fileSize : UInt64 = 0
    
    do {
        
        let attr = try FileManager.default.attributesOfItem(atPath: path)
        fileSize = attr[FileAttributeKey.size] as! UInt64
        
        return fileSize
        
    }
    catch
    {
        print("Error: \(error)")
    }
    return fileSize
}

