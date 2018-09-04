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
    
    typealias Progress = (_ percent: Double, _ completedUnitCount: Double, _ totalCount: Double) -> Void
    typealias Completion = (_ response: (DownloadResponse<Data>)) -> Void
    
    private var requestMap = [String : DownloadRequest?]()
    
    public static let shared = DownloadManager()
    
    private override init() {
        super.init()
    }
}

// MARK: - public methods
extension DownloadManager {
    
    /// 批量下载文件
    ///
    /// - Parameters:
    ///   - urls: 下载地址
    ///   - localURLs: 本地存储地址
    ///   - progress: 进度
    ///   - completion: 完成
    func download(urls: [String], localURLs: [URL], progress: Progress?, completion: ((_ state: Bool) -> Void)?) {
        
        // 获取系统的全局队列
        let _ = DispatchQueue.global(qos: .utility)
        
        // 创建一个下载的Group
        let downloadGroup = DispatchGroup()
        
        // 下载成功个数
        var successCount = 0
        
        // 下载失败个数
        var failCount = 0
        
        /// progress回调次数
        var progressCount = 0
        
        /// progress进度信息
        var progressMap = [String: (receivedLength: Double, totalLength: Double)?]()
        
        let progressBlock = {
            var receivedSize: Double = 0
            var totalSize: Double = 0
            A: for index in 0..<urls.count {
                let url = urls[index]
                let progressData = progressMap[url]
                // 判断所有的请求是否都回调回来，没有回来就结束，此次不block
                if progressData != nil {
                    let (p1,p2) = progressData!!
                    receivedSize += p1
                    totalSize += p2
                    // 最后一条数据，直接block
                    if index == urls.count - 1 {
                        if let progressClosure = progress {
                            progressClosure(receivedSize / totalSize, receivedSize, totalSize)
                        }
                    }
                    continue
                }
                break A
            }
        }
        
        for index in 0..<urls.count {
            let url = urls[index]
            downloadGroup.enter()
            
            download(url: url, localURL: localURLs[index], progress: { (percent, receivedLength, totalLength) in
                
                // 更新progress进度信息
                progressMap[url] = (receivedLength,totalLength)
                
                // 记录progress的block次数
                progressCount += 1
                
                // 每次模为0就处理一次block，减少block次数
                if progressCount % urls.count == 0 {
                    progressBlock()
                }
                
            }) { (response) in
                
                switch response.result {
                case .success(_):
                    successCount += 1
                    if urls.count == successCount {
                        progressBlock()
                    }
                case .failure(_):
                    failCount += 1
                }
                
                downloadGroup.leave()
                
            }
        }
        
        // 当上面所有的任务执行完之后通知
        downloadGroup.notify(queue: .main) {
            if let completionClosure = completion {
                completionClosure(successCount == urls.count ? true: false)
            }
        }
        
    }
    
    /// 下载
    ///
    /// - Parameters:
    ///   - url: 下载地址
    ///   - localURL: 本地存储地址
    ///   - progress: 进度更新
    ///   - completion: 完成
    func download(url: String, localURL: URL, progress: Progress?, completion: Completion?) {
        
        // 判断是否在下载队列中
        if let _ =  requestMap[url] {
            return
        }
        
        // 下载目录配置
        let destination: DownloadRequest.DownloadFileDestination = { temporaryURL, response in
            return (localURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        var downloadRequest: DownloadRequest!
        
        // 判断是否有有效的断点续传信息
        if DownloadResumeManager.shared.isHaveVaildResume(url: url) {
            // 获取断点续传的数据
            let (resumeData, _) = DownloadResumeManager.shared.fetchResumeData(url: url)
            if let resumeData = resumeData {
                downloadRequest = Alamofire.download(resumingWith: resumeData, to: destination)
            } else {
                downloadRequest = Alamofire.download(url, to: destination)
            }
        } else {
            downloadRequest = Alamofire.download(url, to: destination)
        }
        
        downloadRequest.downloadProgress { (progressObject) in
            if let progressClosure = progress {
                progressClosure(progressObject.fractionCompleted, Double(progressObject.completedUnitCount), Double(progressObject.totalUnitCount))
            }
            }.responseData { (downloadResponse) in
                switch downloadResponse.result {
                case .success(_): // let data
                    DownloadResumeManager.shared.deleteResumeData(url: url)
                case .failure(_): // let error
                    // TODO: 判断是否支持断点续传
                    DownloadResumeManager.shared.saveResumeData(url: url, resumeData: downloadResponse.resumeData)
                }
                
                self.requestMap.removeValue(forKey: url)
                
                if let completionClosure = completion {
                    completionClosure(downloadResponse)
                }
        }
        
        requestMap[url] = downloadRequest
        
    }
    
    /// 取消下载
    ///
    /// - Parameter url: 下载地址
    func cancel(url: String) {
        guard let downloadRequest =  requestMap[url] else {
            return
        }
        downloadRequest?.cancel()
    }
    
    /// 批量取消下载
    ///
    /// - Parameter urls: 下载地址
    func cancel(urls: [String]) {
        for item in urls {
            cancel(url: item)
        }
    }
}
