//
//  LogUtil.swift
//  DownloadResume
//
//  Created by 乔晓松 on 2018/9/4.
//  Copyright © 2018年 Coolspan. All rights reserved.
//

import UIKit

// Debug 日志打印
func DRLog<T>(_ message : T, file : String = #file, lineNumber : Int = #line) {
    
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    //    print("[\(fileName):line:\(lineNumber)]- \(message)")
    NSLog("[\(fileName):line:\(lineNumber)]- \(message)")
    #endif
}

