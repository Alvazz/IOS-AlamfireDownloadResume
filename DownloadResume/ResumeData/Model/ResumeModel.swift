//
//  ResumeModel.swift
//  DownloadResume
//
//  Created by 乔晓松 on 2018/8/31.
//  Copyright © 2018年 Coolspan. All rights reserved.
//

import Foundation
import RealmSwift

// 断点续传实体类
class ResumeModel: Object {
    
    /// 下载地址
    @objc dynamic var url: String = ""
    
    /// 断点续传信息
    @objc dynamic var resumeData: Data?
    
    /// 已经下载的长度
    @objc dynamic var resumeBytesReceived: Double = 0
    
    /// 临时文件名
    @objc dynamic var tempFileName: String = ""
    
    /// 更新时间
    @objc dynamic var updateTime: Double = Date().timeIntervalSince1970
    
    override static func primaryKey() -> String? {
        return "url"
    }
    
}

// MARK: - public methods
extension ResumeModel {
    
    /// 获取下载的临时文件名
    ///
    /// - Returns: 临时文件名
    static func getTmpFileName(resumeData: Data) -> String? {
        guard let result = try? PropertyListSerialization.propertyList(from: resumeData, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        if let result = result {
            if let fileName = result["NSURLSessionResumeInfoTempFileName"] as? String {
                return fileName
            }
        }
        return nil
    }
    
    /// 获取当前已经下载的字节长度
    ///
    /// - Returns: 长度
    static func receivedBytes(resumeData: Data) -> Double {
        guard let result = try? PropertyListSerialization.propertyList(from: resumeData, options: [], format: nil) as? [String: Any] else {
            return -1
        }
        if let result = result {
            if let fileName = result["NSURLSessionResumeBytesReceived"] as? Double {
                return fileName
            }
        }
        return -1
    }
    
    static func changeResumeData(resumeData: Data) -> Data? {
        
        return nil
    }
}
