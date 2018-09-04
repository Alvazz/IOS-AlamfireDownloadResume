//
//  ViewController.swift
//  DownloadResume
//
//  Created by 乔晓松 on 2018/8/30.
//  Copyright © 2018年 Coolspan. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    let videoURL = "https://dl-android.keepcdn.com/keep-latest_7ee136cd6244b8a53a40ccf373902c55.apk?download/Keep%E7%91%9C%E4%BC%BD%E8%B7%91%E6%AD%A5%E5%81%A5%E8%BA%AB%E9%AA%91%E8%A1%8C%E6%95%99%E7%BB%83-latest.apk"
    
    @IBOutlet weak var progressSingleView: UIProgressView!
    
    @IBOutlet weak var progressMoreView: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let documentURL = FileManager.default.urls(for: .cachesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
        DRLog("documentURL: \(documentURL)")
        
    }
    
    @IBAction func downloadStart(_ sender: UIButton) {
        print("开始下载……")
        
        let documentURL = FileManager.default.urls(for: .cachesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
        
        try! FileManager.default.createDirectory(at: documentURL
            .appendingPathComponent("video", isDirectory: true), withIntermediateDirectories: true, attributes: nil)
        
        let filePath = documentURL
            .appendingPathComponent("video", isDirectory: true)
            .appendingPathComponent("test.apk")
        
        DownloadManager.shared.download(url: videoURL, localURL: filePath, progress: { (percent, receivedLength, totalLength) in
            DRLog("percent: \(percent)")
            self.progressSingleView.setProgress(Float(percent), animated: true)
        }) { (response) in
            DRLog("response: \(response.result)")
        }
    }
    
    @IBAction func downloadCancel(_ sender: UIButton) {
        print("取消下载……")
        DownloadManager.shared.cancel(url: videoURL)
    }
    
    @IBAction func downloadMoreStart(_ sender: UIButton) {
        print("开始批量下载……")
        let urls = getUrls()
        let localURLs = getLocalURLS()
        
        DownloadManager.shared.download(urls: urls, localURLs: localURLs, progress: { (percent, receivedLength, totalLength) in
            DRLog("percent: \(percent)")
            self.progressMoreView.setProgress(Float(percent), animated: true)
        }) { (state) in
            DRLog("批量下载结束: \(state)")
        }
    }
    
    @IBAction func downloadMoreCancel(_ sender: UIButton) {
        print("取消批量下载……")
        let urls = getUrls()
        DownloadManager.shared.cancel(urls: urls)
    }
    
    @IBAction func exitApp(_ sender: UIButton) {
        print("退出App……")
        exit(0)
    }
}

// MARK: - private methods
private extension ViewController {
    
    func getUrls() -> [String] {
        var urls = [String]()
        urls.append("http://download.sj.qq.com/upload/connAssitantDownload/upload/MobileAssistant_1.apk")
        urls.append("https://qd.myapp.com/myapp/qqteam/AndroidQQ/mobileqq_android.apk")
        urls.append("https://dldir1.qq.com/weixin/android/weixin672android1340.apk")
        urls.append("https://static1.keepcdn.com/chaos/0728/A031C068_main_s.mp4")
        urls.append("https://static1.keepcdn.com/chaos/0728/B043C023_main_s.mp4")
        return urls
    }
    
    func getLocalURLS() -> [URL] {
        var localURLs = [URL]()
        
        let documentURL = FileManager.default.urls(for: .cachesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
        
        try! FileManager.default.createDirectory(at: documentURL
            .appendingPathComponent("video", isDirectory: true), withIntermediateDirectories: true, attributes: nil)
        
        let urls = getUrls()
        for index in 0..<urls.count {
            let documentURL = FileManager.default.urls(for: .cachesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
            let filePath = documentURL
                .appendingPathComponent("video", isDirectory: true)
                .appendingPathComponent("test\(index).apk")
            localURLs.append(filePath)
        }
        
        return localURLs
    }
}

