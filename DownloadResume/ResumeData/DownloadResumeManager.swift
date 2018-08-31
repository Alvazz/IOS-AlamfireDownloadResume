//
//  DownloadResumeManager.swift
//  DownloadResume
//
//  Created by 乔晓松 on 2018/8/31.
//  Copyright © 2018年 Coolspan. All rights reserved.
//

import UIKit
//import CryptoSwift

/// 下载任务断点续传管理
class DownloadResumeManager: NSObject {
    
    public static let shared = DownloadResumeManager()
    
    private override init() {
        super.init()
    }
}

// MARK: - public methods
extension DownloadResumeManager {
    
    /// 自动清理长时间不使用的数据
    func autoClear() {
        
    }
    
    /// 判断是否有有效的断点续传数据
    ///
    /// - Parameter url: 下载地址
    /// - Returns: 是否
    func isHaveVaildResume(url: String) -> Bool {
        // 读取数据库，查看是否有对应的数据
        let element = DataBaseManager.shared.getByPrimaryKey(type: ResumeModel.self, key: url)
        if let ele = element { // 数据存在
            DLog("断点续传数据库存在: \(ele)")
            
            guard let resumeData = ele.resumeData else {
                return false
            }
            
            // 获取临时下载的文件名称
            let tmpFileNameStr = ResumeModel.getTmpFileName(resumeData: resumeData)
            guard let tmpFileName = tmpFileNameStr else { // 如果名字获取不到，直接终止处理
                return false
            }
            
            let documentURL = FileManager.default.urls(for: .cachesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
            
            // 备份的临时下载文件地址
            let cacheURL = documentURL
                .appendingPathComponent("ResumeDataCaches", isDirectory: true)
                .appendingPathComponent(tmpFileName)
            
            if FileUtil.isExists(path: cacheURL.path) {
                // 读取临时文件的大小
                let realFileSize = FileUtil.fileSize(path: cacheURL.path)
                
                // 判断文件大小和断点续传的大小是否一致
                if ele.resumeBytesReceived == realFileSize {
                    return true
                }
                
                return false
            } else {
                return false
            }
        } else { // 数据不存在
            DLog("断点续传数据库不存在")
            return false
        }
    }
    
    /// 获取resumeData，使用该方法之前需要先判断文件的有效性
    ///
    /// - Parameter url: 地址
    /// - Returns: resumeData
    func fetchResumeData(url: String) -> (resumeData: Data?, url: URL?) {
        let element = DataBaseManager.shared.getByPrimaryKey(type: ResumeModel.self, key: url)
        if let ele = element {
            let tmpFilePath = "\(NSTemporaryDirectory())\(ele.tempFileName)"
            // 判断是否存在
            if FileUtil.isExists(path: tmpFilePath) { // 存在
                // 读取临时文件的大小
                let realFileSize = FileUtil.fileSize(path: tmpFilePath)
                // 判断文件大小和断点续传的大小是否一致
                if ele.resumeBytesReceived == realFileSize {
                    return (ele.resumeData, URL(fileURLWithPath: tmpFilePath))
                }
                FileUtil.delete(url: URL(fileURLWithPath: tmpFilePath))
            }
            // 不存在
            
            let cachesDirectoryURL = FileManager.default.urls(for: .cachesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
            
            // 备份的临时下载文件地址
            let cacheURLDir = cachesDirectoryURL
                .appendingPathComponent("ResumeDataCaches", isDirectory: true)
            
            try! FileManager.default.createDirectory(at: cacheURLDir, withIntermediateDirectories: true, attributes: nil)
            
            let cacheURL = cacheURLDir.appendingPathComponent(ele.tempFileName)
            
            if !FileUtil.isExists(path: cacheURL.path) {
                // 删除数据库记录
                deleteResumeData(url: url)
                return (nil, nil)
            }
            
            let realFileSize = FileUtil.fileSize(path: cacheURL.path)
            // 判断文件大小和断点续传的大小是否一致
            if ele.resumeBytesReceived != realFileSize {
                // 删除数据库记录
                deleteResumeData(url: url)
                return (nil, nil)
            }
            
            // 备份临时下载的文件
            try? FileManager.default.copyItem(at: cacheURL, to: URL(fileURLWithPath: tmpFilePath))
            
            // 获取复制后的文件大小
            let cacheSize = FileUtil.fileSize(path: cacheURL.path)
            
            // 判断复制前后的文件大小是否一致
            if cacheSize != realFileSize {
                return (nil, nil)
            }
            return (ele.resumeData, URL(fileURLWithPath: tmpFilePath))
        }
        
        return (nil, nil)
    }
    
    /// 保存断点续传数据
    ///
    /// - Parameters:
    ///   - url: 下载地址
    ///   - resumeData: resumeData
    func saveResumeData(url: String, resumeData data: Data?) {
        // 判断内容是空，空不处理
        guard let resumeData = data else {
            DLog("saveResumeData 保存失败1")
            return
        }
        // 读取数据库，查看是否有对应的数据
        let element = DataBaseManager.shared.getByPrimaryKey(type: ResumeModel.self, key: url)
        
        // 获取临时下载的文件名称
        let tmpFileNameStr = ResumeModel.getTmpFileName(resumeData: resumeData)
        guard let tmpFileName = tmpFileNameStr else { // 如果名字获取不到，直接终止处理
            DLog("saveResumeData 保存失败2")
            return
        }
        
        // 下载文件的临时文件路径
        let tmpFilePath = "\(NSTemporaryDirectory())\(tmpFileName)"
        // 判断是否存在
        if !FileUtil.isExists(path: tmpFilePath) { // 临时下载文件不存在，终止处理
            DLog("saveResumeData 保存失败3")
            return
        }
        
        // 读取已经下载的长度
        let receivedBytes = ResumeModel.receivedBytes(resumeData: resumeData)
        // 判断返回的是否是默认值
        guard receivedBytes != -1 else { // 获取不到已经下载的长度，终止处理
            DLog("saveResumeData 保存失败4")
            return
        }
        
        // 读取临时文件的大小
        let realFileSize = FileUtil.fileSize(path: tmpFilePath)
        
        // 判断文件大小和断点续传的大小是否一致
        if receivedBytes != realFileSize {
            return
        }
        
        let cachesDirectoryURL = FileManager.default.urls(for: .cachesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
        
        // 优化: 暂时不考虑文件重名的情况
        //        let newTmpName = url.bytes.md5().toHexString()
        
        // 备份的临时下载文件地址
        let cacheURLDir = cachesDirectoryURL
            .appendingPathComponent("ResumeDataCaches", isDirectory: true)
        
        try! FileManager.default.createDirectory(at: cacheURLDir, withIntermediateDirectories: true, attributes: nil)
        
        let cacheURL = cacheURLDir.appendingPathComponent(tmpFileName)
        
        // 判断文件是否存在，存在就删除
        if FileUtil.isExists(path: cacheURL.path) {
            FileUtil.delete(url: cacheURL)
        }
        
        // 备份临时下载的文件
        try? FileManager.default.copyItem(at: URL(fileURLWithPath: tmpFilePath), to: cacheURL)
        
        // 获取复制后的文件大小
        let cacheSize = FileUtil.fileSize(path: cacheURL.path)
        
        // 判断复制前后的文件大小是否一致
        if cacheSize != realFileSize {
            DLog("saveResumeData 保存失败5: tmpFileName: \(tmpFileName)")
            return
        }
        if let ele = element { // 存在，更新数据
            // 更新数据
            DataBaseManager.shared.update {
                ele.resumeData = resumeData
                ele.resumeBytesReceived = receivedBytes
                ele.updateTime = Date().timeIntervalSince1970
                DataBaseManager.shared.updateInTransaction(object: ele)
            }
            DLog("saveResumeData: 更新ResumeData数据成功")
        } else { // 不存在，插入数据
            let ele = ResumeModel()
            ele.url = url
            ele.updateTime = Date().timeIntervalSince1970
            ele.resumeData = resumeData
            ele.resumeBytesReceived = receivedBytes
            ele.tempFileName = tmpFileName
            DataBaseManager.shared.add(object: ele)
            DLog("saveResumeData: 插入ResumeData数据成功")
        }
    }
    
    /// 删除指定的数据
    ///
    /// - Parameter url: 下载地址
    func deleteResumeData(url: String) {
        // 读取数据库，查看是否有对应的数据
        let element = DataBaseManager.shared.getByPrimaryKey(type: ResumeModel.self, key: url)
        if let ele = element {
            let cachesDirectoryURL = FileManager.default.urls(for: .cachesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
            
            // 备份的临时下载文件地址
            let cacheURLDir = cachesDirectoryURL
                .appendingPathComponent("ResumeDataCaches", isDirectory: true)
            
            let cacheURL = cacheURLDir.appendingPathComponent(ele.tempFileName)
            
            if FileUtil.isExists(path: cacheURL.path) {
                FileUtil.delete(url: cacheURL)
            }
            DataBaseManager.shared.delete(object: ele)
            DLog("删除数据成功")
        } else {
            DLog("删除数据失败")
        }
    }
}

// Debug 日志打印
func DLog<T>(_ message : T, file : String = #file, lineNumber : Int = #line) {
    
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    //    print("[\(fileName):line:\(lineNumber)]- \(message)")
    NSLog("[\(fileName):line:\(lineNumber)]- \(message)")
    #endif
}
