//
//  DownloadManager.swift
//  DownloadResume
//
//  Created by 乔晓松 on 2018/8/30.
//  Copyright © 2018年 Coolspan. All rights reserved.
//

import UIKit
import Alamofire

class DownloadManager: NSObject {

    public static let shared = DownloadManager()
    
    var request: DownloadRequest?
    
    private override init() {
        
    }
}

extension DownloadManager {
    
    func start() {
        resumeDown()
    }
    
    func resumeDown() {
        let videoURL = "https://dl-android.keepcdn.com/keep-latest_7ee136cd6244b8a53a40ccf373902c55.apk?download/Keep%E7%91%9C%E4%BC%BD%E8%B7%91%E6%AD%A5%E5%81%A5%E8%BA%AB%E9%AA%91%E8%A1%8C%E6%95%99%E7%BB%83-latest.apk"
        
        let documentURL = FileManager.default.urls(for: .cachesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
        
        try! FileManager.default.createDirectory(at: documentURL
            .appendingPathComponent("video", isDirectory: true), withIntermediateDirectories: true, attributes: nil)
        
        let filePath = documentURL
            .appendingPathComponent("video", isDirectory: true)
            .appendingPathComponent("test.apk")
        
        let localURL = filePath
        
        let destination: DownloadRequest.DownloadFileDestination = { temporaryURL, response in
            return (localURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        if DownloadResumeManager.shared.isHaveVaildResume(url: videoURL) {
            DLog("断点续传下载...")
            let (resumeData1, url1) = DownloadResumeManager.shared.fetchResumeData(url: videoURL)
            if let resumeData = resumeData1, let _ = url1 {
                
                request = Alamofire.download(resumingWith: resumeData, to: destination)
                    .downloadProgress { (progressObject) in
                        print("downloadProgress: \(progressObject)")
                    }
                    .responseData { (reponseData) in
                        switch reponseData.result {
                        case .success(let data):
                            self.request = nil
                            print("download resume成功....\(data)")
                            DownloadResumeManager.shared.deleteResumeData(url: videoURL)
                        case .failure(let error):
                            print("download resume失败....\(error)")
                            DownloadResumeManager.shared.saveResumeData(url: videoURL, resumeData: reponseData.resumeData)
                        }
                }
                return
            }
        }
        request =  Alamofire.download(videoURL, to: destination)
            .downloadProgress { (progressObject) in
                print("downloadProgress: \(progressObject)")
            }
            .responseData { (reponseData) in
                switch reponseData.result {
                case .success(let data):
                    self.request = nil
                    print("download成功....\(data)")
                    DownloadResumeManager.shared.deleteResumeData(url: videoURL)
                case .failure(let error):
                    print("download失败....\(error)")
                    DownloadResumeManager.shared.saveResumeData(url: videoURL, resumeData: reponseData.resumeData)
                }
        }
        DLog("新文件下载...")
    }
    
    func downloadResume() {
        let documentURL = FileManager.default.urls(for: .documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
        
        let resumeTmpPath = documentURL
            .appendingPathComponent("cache", isDirectory: true)
            .appendingPathComponent("resumeData.tmp")
        
        if FileManager.default.fileExists(atPath: resumeTmpPath.path) {
            print("临时文件存在...:\(resumeTmpPath)")
            do {
                let dictArray = NSDictionary.init(contentsOf: resumeTmpPath)
                guard let resultData = dictArray as? [String : NSObject] else {
                    return
                }
                let offsetSize = resultData["NSURLSessionResumeBytesReceived"]
                let tmpS = "\(NSTemporaryDirectory())\(resultData["NSURLSessionResumeInfoTempFileName"]!)"
                print("Temp: \(resultData["NSURLSessionResumeInfoTempFileName"]!)")
                let size = try FileManager.default.attributesOfItem(atPath: tmpS)[FileAttributeKey.size] as! UInt64
                
                let dict = try FileManager.default.attributesOfItem(atPath: tmpS) as NSDictionary
                let fileSize = Int(dict.fileSize())
                
                print("tmpS: \(tmpS) exists: \(FileManager.default.fileExists(atPath: tmpS))  size: \(size)  fileSize: \(fileSize)  offsetSize: \(offsetSize)")
                
                let filePath = documentURL
                    .appendingPathComponent("video", isDirectory: true)
                    .appendingPathComponent("test.apk")

                let localURL = filePath

                let destination: DownloadRequest.DownloadFileDestination = { temporaryURL, response in
                    print("temporaryURL: \(temporaryURL)")
                    print("localURL: \(localURL)")
                    return (localURL, [.removePreviousFile, .createIntermediateDirectories])
                }

                let resumeData = try Data.init(contentsOf: resumeTmpPath)
                request = Alamofire.download(resumingWith: resumeData, to: destination)
                    .downloadProgress { (progressObject) in
                        print("downloadProgress: \(progressObject)")
                    }
                    .responseData { (reponseData) in
                        switch reponseData.result {
                        case .success(let data):
                            print("成功....\(data)")
                        case .failure(let error):
                            print("失败....\(error)")

                            print("失败resumeData.... \(reponseData.resumeData)")
                            
                            let tmp1 = ResumeModel.getTmpFileName(resumeData: reponseData.resumeData!)
                            let tmp11 = ResumeModel.receivedBytes(resumeData: reponseData.resumeData!)
//                            let data = ResumeModel.changeResumeData(resumeData: reponseData.resumeData!)
//                            let tmp2 = ResumeModel.getTmpFileName(resumeData: data!)
                            DLog("tmp1: \(tmp1)  tmp11:\(tmp11)")
                            
                            let resumeTmpPath = documentURL
                                .appendingPathComponent("cache", isDirectory: true)
                                .appendingPathComponent("resumeData.tmp")
                            if let resumeData = reponseData.resumeData {
                                do {
                                    try FileManager.default.createDirectory(at: documentURL
                                        .appendingPathComponent("cache", isDirectory: true), withIntermediateDirectories: true, attributes: nil)

                                    if FileManager.default.fileExists(atPath: resumeTmpPath.absoluteString) {
                                        try FileManager.default.removeItem(at: resumeTmpPath)
                                    }

                                    try resumeData.write(to: resumeTmpPath, options: Data.WritingOptions.atomic)
                                    print(":resumeTmpPath: \(resumeTmpPath)")
                                } catch let error {
                                    print("error: \(error)")
                                }
                            }
                        }

                }
            } catch let error {
                print("error: \(error)")
            }
        } else {
            print("临时文件不存在2...:\(resumeTmpPath.path)")
            download()
        }
    }
    
    func download() {
        let videoURL = "https://dl-android.keepcdn.com/keep-latest_7ee136cd6244b8a53a40ccf373902c55.apk?download/Keep%E7%91%9C%E4%BC%BD%E8%B7%91%E6%AD%A5%E5%81%A5%E8%BA%AB%E9%AA%91%E8%A1%8C%E6%95%99%E7%BB%83-latest.apk"
        
        let documentURL = FileManager.default.urls(for: .documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
        let filePath = documentURL
            .appendingPathComponent("video", isDirectory: true)
            .appendingPathComponent("test.apk")
        
        let localURL = filePath
        
        let destination: DownloadRequest.DownloadFileDestination = { temporaryURL, response in
            print("temporaryURL: \(temporaryURL)")
            print("localURL: \(localURL)")
            return (localURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        request =  Alamofire.download(videoURL, to: destination)
            .downloadProgress { (progressObject) in
                print("downloadProgress: \(progressObject)")
            }
            .responseData { (reponseData) in
                switch reponseData.result {
                case .success(let data):
                    print("成功....\(data)")
                case .failure(let error):
                    print("失败....\(error)")
                    
                    print("失败resumeData.... \(reponseData.resumeData)")
                    let resumeTmpPath = documentURL
                        .appendingPathComponent("cache", isDirectory: true)
                        .appendingPathComponent("resumeData.tmp")
                    if let resumeData = reponseData.resumeData {
                        do {
                            try FileManager.default.createDirectory(at: documentURL
                                .appendingPathComponent("cache", isDirectory: true), withIntermediateDirectories: true, attributes: nil)
                            
                            if FileManager.default.fileExists(atPath: resumeTmpPath.absoluteString) {
                                try FileManager.default.removeItem(at: resumeTmpPath)
                            }

                            try resumeData.write(to: resumeTmpPath, options: Data.WritingOptions.atomic)
                            print(":resumeTmpPath: \(resumeTmpPath)")
                        } catch let error {
                            print("error: \(error)")
                        }
                    }
                }
        }
    }
    
    func pause() {
        request?.suspend()
//        Alamofire.SessionManager.default.session.getAllTasks { (tasks) in
//            print("全部任务个数:\(tasks.count)")
//            for task in tasks {
//                task.suspend()
//            }
//        }
    }
    
    func cancel() {
        request?.cancel()
//        Alamofire.SessionManager.default.session.getAllTasks { (tasks) in
//            print("全部任务个数:\(tasks.count)")
//            for task in tasks {
//
//            }
//        }
    }
}
