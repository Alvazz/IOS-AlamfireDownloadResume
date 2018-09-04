//
//  DownloadResumeManager.swift
//  DownloadResume
//
//  Created by 乔晓松 on 2018/8/31.
//  Copyright © 2018年 Coolspan. All rights reserved.
//

import UIKit

/// 下载任务断点续传管理
class DownloadResumeManager: NSObject {
    
    // 缓存目录/Library/Caches/ResumeDataCaches/
    private let BACK_DIRECTORY_NAME = "ResumeDataCaches"
    
    public static let shared = DownloadResumeManager()
    
    private override init() {
        super.init()
    }
    
    /// 获取指定名称的备份文件的地址
    ///
    /// - Parameter tempFileName: 文件名称
    /// - Returns: URL地址
    private func getBackTempFileURL(tempFileName: String) -> URL {
        // 获取缓存的目录
        let cachesDirectoryURL = FileManager.default.urls(for: .cachesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
        
        // 备份的临时下载文件目录
        let cacheURLDir = cachesDirectoryURL
            .appendingPathComponent(BACK_DIRECTORY_NAME, isDirectory: true)
        
        // 创建备份目录
        try! FileManager.default.createDirectory(at: cacheURLDir, withIntermediateDirectories: true, attributes: nil)
        
        // 得到文件地址
        let cacheURL = cacheURLDir.appendingPathComponent(tempFileName)
        
        return cacheURL
    }
    
    /// 判断数据是否有效
    ///
    /// - Parameters:
    ///   - url: 下载地址
    ///   - element: Resume Element
    /// - Returns: 是否有效
    private func isHaveVaildResume(url: String, element: ResumeModel?) -> Bool {
        if let ele = element { // 数据存在
            DRLog("断点续传数据库存在: \(ele)")
            guard let resumeData = ele.resumeData else {
                // 删除数据库记录
                deleteResumeData(url: url)
                return false
            }
            
            // 备份的临时下载文件地址
            let cacheURL = getBackTempFileURL(tempFileName: ele.tempFileName)
            
            if FileUtil.isExists(path: cacheURL.path) {
                // 读取临时文件的大小
                let realFileSize = FileUtil.fileSize(path: cacheURL.path)
                
                let resumeBytesReceived = ResumeModel.receivedBytes(resumeData: resumeData)
                
                if resumeBytesReceived != ele.resumeBytesReceived {
                    DRLog("数据库信息不一致，请处理????????????")
                    return false
                }
                
                // 判断文件大小和断点续传的大小是否一致
                if ele.resumeBytesReceived == realFileSize {
                    return true
                }
                // 删除数据库记录
                deleteResumeData(url: url)
                return false
            } else {
                return false
            }
        } else { // 数据不存在
            DRLog("断点续传数据库不存在")
            return false
        }
    }
    
    /// 删除指定名字的备份缓存文件
    ///
    /// - Parameter tempFileName: 临时文件名称
    private  func deleteCache(tempFileName: String) {
        // 获取备份缓存地址
        let cacheURL = getBackTempFileURL(tempFileName: tempFileName)
        
        // 判断是否存在，存在就删除
        if FileUtil.isExists(path: cacheURL.path) {
            FileUtil.delete(url: cacheURL)
        }
    }
    
}

// MARK: - public methods
extension DownloadResumeManager {
    
    /// 启动
    func start() {
        // 先启动清理任务
        self.autoClear()
        // 初始化数据库配置
        DataBaseManager.shared.setup()
    }
    
    /// 自动清理长时间不使用的数据
    func autoClear() {
        DispatchQueue.main.async {
            // 指定过期时间，15天以上的数据判定为无效过期数据
            let endTime: Double = Date().timeIntervalSince1970 - 15 * 24 * 60 * 60
            
            DataBaseManager.shared.getAll(type: ResumeModel.self, onResult: { (results) in
                let dealList = results.filter(NSPredicate.init(format: "updateTime < \(endTime)"))
                if dealList.count > 0 {
                    for item in dealList {
                        self.deleteCache(tempFileName: item.tempFileName)
                        DataBaseManager.shared.deleteInTransaction(object: item)
                    }
                }
                DRLog("自动清理长时间不使用的数据: \(dealList.count)")
            })
        }
    }
    
    /// 判断是否有有效的断点续传数据
    ///
    /// - Parameter url: 下载地址
    /// - Returns: 是否
    func isHaveVaildResume(url: String) -> Bool {
        //        DRLog("")
        // 读取数据库，查看是否有对应的数据
        let element = DataBaseManager.shared.getByPrimaryKey(type: ResumeModel.self, key: url)
        return isHaveVaildResume(url: url, element: element)
    }
    
    /// 获取已经下载的长度
    ///
    /// - Parameter url: 狭隘地址
    /// - Returns: 字节长度
    func fetchReceivedBytes(url: String) -> Double {
        let element = DataBaseManager.shared.getByPrimaryKey(type: ResumeModel.self, key: url)
        if let ele = element {
            let resumeBytesReceived = ele.resumeBytesReceived
            if isHaveVaildResume(url: url, element: element) {
                return resumeBytesReceived
            }
        }
        return 0
    }
    
    /// 获取resumeData，使用该方法之前需要先判断文件的有效性
    ///
    /// - Parameter url: 地址
    /// - Returns: resumeData
    func fetchResumeData(url: String) -> (resumeData: Data?, url: URL?) {
        let element = DataBaseManager.shared.getByPrimaryKey(type: ResumeModel.self, key: url)
        if let ele = element {
            guard let _ = ele.resumeData else {
                // 删除数据库记录
                deleteResumeData(url: url)
                return (nil, nil)
            }
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
            
            let cacheURL = getBackTempFileURL(tempFileName: ele.tempFileName)
            
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
            let cacheSize = FileUtil.fileSize(path: tmpFilePath)
            
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
            DRLog("saveResumeData 保存失败1")
            return
        }
        
        // 获取临时下载的文件名称
        let tmpFileNameStr = ResumeModel.getTmpFileName(resumeData: resumeData)
        guard let tmpFileName = tmpFileNameStr else { // 如果名字获取不到，直接终止处理
            DRLog("saveResumeData 保存失败2")
            return
        }
        
        // 下载文件的临时文件路径
        let tmpFilePath = "\(NSTemporaryDirectory())\(tmpFileName)"
        // 判断是否存在
        if !FileUtil.isExists(path: tmpFilePath) { // 临时下载文件不存在，终止处理
            DRLog("saveResumeData 保存失败3")
            return
        }
        
        // 读取已经下载的长度
        let receivedBytes = ResumeModel.receivedBytes(resumeData: resumeData)
        // 判断返回的是否是默认值
        guard receivedBytes != -1 else { // 获取不到已经下载的长度，终止处理
            DRLog("saveResumeData 保存失败4")
            return
        }
        
        // 读取临时文件的大小
        let realFileSize = FileUtil.fileSize(path: tmpFilePath)
        
        // 判断文件大小和断点续传的大小是否一致
        if receivedBytes != realFileSize {
            return
        }
        
        // 优化: 暂时没有考虑文件重名的情况
        
        let cacheURL = getBackTempFileURL(tempFileName: tmpFileName)
        
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
            DRLog("saveResumeData 保存失败5: tmpFileName: \(tmpFileName)")
            return
        }
        
        // 读取数据库，查看是否有对应的数据
        let element = DataBaseManager.shared.getByPrimaryKey(type: ResumeModel.self, key: url)
        
        if let ele = element { // 存在，更新数据
            // 更新数据
            DataBaseManager.shared.update {
                ele.resumeData = resumeData
                ele.resumeBytesReceived = receivedBytes
                ele.updateTime = Date().timeIntervalSince1970
                DataBaseManager.shared.updateInTransaction(object: ele)
            }
            DRLog("saveResumeData: 更新ResumeData数据成功")
        } else { // 不存在，插入数据
            let ele = ResumeModel()
            ele.url = url
            ele.updateTime = Date().timeIntervalSince1970
            ele.resumeData = resumeData
            ele.resumeBytesReceived = receivedBytes
            ele.tempFileName = tmpFileName
            DataBaseManager.shared.add(object: ele)
            DRLog("saveResumeData: 插入ResumeData数据成功")
        }
    }
    
    /// 删除指定的数据
    ///
    /// - Parameter url: 下载地址
    func deleteResumeData(url: String) {
        // 读取数据库，查看是否有对应的数据
        let element = DataBaseManager.shared.getByPrimaryKey(type: ResumeModel.self, key: url)
        if let ele = element {
            deleteCache(tempFileName: ele.tempFileName)
            // 此处不能直接使用ele, 会出现Object has been deleted or invalidated.
            DataBaseManager.shared.delete(object: ele)
            DRLog("删除数据成功")
        } else {
            DRLog("删除数据,没有对应的数据")
        }
    }
    
    /// 打印所有任务
    func printAll() {
        DataBaseManager.shared.getAll(type: ResumeModel.self) { (eles) in
            for item in eles {
                if let result = try? PropertyListSerialization.propertyList(from: item.resumeData!, options: [], format: nil) as? [String: Any] {
                    DRLog("print re: \(result)")
                    DRLog("NSURLSessionDownloadURL: \(result!["NSURLSessionDownloadURL"])")
                }
            }
        }
    }
}

