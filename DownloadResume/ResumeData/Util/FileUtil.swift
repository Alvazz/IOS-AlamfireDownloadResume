//
//  FileUtil.swift
//  DownloadResume
//
//  Created by 乔晓松 on 2018/8/31.
//  Copyright © 2018年 Coolspan. All rights reserved.
//

import UIKit

class FileUtil {

    /// 文件是否存在
    ///
    /// - Parameter path: 文件路径
    /// - Returns: 是否存在
    class func isExists(path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// 获取文件大小
    ///
    /// - Parameter path: 文件路径
    /// - Returns: 文件大小
    class func fileSize(path: String) -> Double {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        if let attributes = attributes {
            let size = attributes[FileAttributeKey.size]
            if let fileSize = size as? Double {
                return fileSize
            }
        }
        return -1
    }
    
    /// 删除文件
    ///
    /// - Parameter url: 路径URL
    class func delete(url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
}
