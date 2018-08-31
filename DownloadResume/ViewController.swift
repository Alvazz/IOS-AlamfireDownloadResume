//
//  ViewController.swift
//  DownloadResume
//
//  Created by 乔晓松 on 2018/8/30.
//  Copyright © 2018年 Coolspan. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    @IBAction func downloadStart(_ sender: UIButton) {
        print("开始下载……")
        DownloadManager.shared.start()
    }
    
    @IBAction func downloadPause(_ sender: UIButton) {
        print("暂停下载……")
        DownloadManager.shared.pause()
        
    }
    
    @IBAction func downloadCancel(_ sender: UIButton) {
        print("取消下载……")
        DownloadManager.shared.cancel()
    }
    
    @IBAction func exitApp(_ sender: UIButton) {
        print("退出App……")
        exit(0)
    }
}

extension ViewController {
    
    
    
}

