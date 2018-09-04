# IOS-AlamfireDownloadResume
![](https://img.shields.io/badge/platform-ios-lightgrey.svg)  ![](https://img.shields.io/badge/language-swift-orange.svg)  [![codebeat badge](https://codebeat.co/badges/77ca5356-df91-4ab1-bbfc-930897948f19)](https://codebeat.co/projects/github-com-coolspan-livewallpaper-master)  ![](https://img.shields.io/badge/license-Apache-000000.svg)  [![](https://img.shields.io/badge/CSDN-@qxs965266509-green.svg)](https://blog.csdn.net/qxs965266509)




### 效果图：

![动态壁纸](https://github.com/coolspan/IOS-AlamfireDownloadResume/blob/master/screenshots/downresume.gif)

### 知识点

ios中的目录: 了解或熟悉的请跳过此段；

```
1.AppName.app目录: 这是应用程序的程序包目录，包含应用程序的本身，由于应用程序必须经过签名，所以您在运行时不能对这个目录中的内容进行修改，否则可能会是应用程序无法启动。包含下述三个文件夹: Documents、Library、tmp；
2.Documents目录: 应该讲所有的应用程序数据文件写入到这个目录中。这个目录用于存储用户数据或其他应该定期备份的信息。iTunes会自动备份这里面的文件；
    例子: 游戏进度，涂鸦软件的绘图
    注: 不要保存从网络上下载的文件，否则会无法上架
3.Library目录: 这个目录下有两个子目录: Caches、Preferences
    3.1 Caches目录: 用于存放应用程序专用的支持文件，保存应用程序再次启动过程中需要的信息；保存应用运行时生成的需要持久化的数据，iTunes不备份该目录；一般存放体积大，不需要备份的非重要数据；保存临时文件，例如：缓存的图片，离线数据(地图数据);系统不会清理cache目录中的文件；就要求程序开发时，必须提供cache目录的清理解决方案；
    3.2 Preferences目录: 包含应用程序的偏好设置文件。不应该直接创建偏好设置文件，而是应该使用UserDefaults类来取得和设置应用程序的偏好；如果想要数据及时写入硬盘，还需要调用一个同步方法synchronize();
    例子：杂志、新闻、地图应用使用的数据库缓存文件和可下载内容应该保存到Library文件中
4.tmp目录: 这个目录用户存放临时文件，保存应用程序再次启动过程中不需要的信息；iCloud不会备份此目录文件；应用没有运行，系统也可能会清除该目录下的文件；重新启动手机，tmp目录会被清空；系统磁盘空间不足时，系统也会自动清理；
```

Http断点续传:

> 参考文章: <http://blog.sina.com.cn/s/blog_ec8c9eae0102x3uu.html>

### 网络库

```
pod 'Alamfire'
```

### 需求

> 使用Alamfire实现文件的断点续传，不管是用户取消还是异常停止下载，都可以继续断点下载，减少用户的使用流量，提高用户体验

### 遇到的问题

问题描述:

> 1.Alamfire在下载时，会在下载到tmp临时文件中，当下载完成后才会移到下载时指定的目录中；
>
> 2.根据tmp目录的解释，tmp目录中的文件可能会被删除掉，导致下次重新打开App后，可能临时文件不存在而不能继续下载；
>
> 3.怎么判断或保存下载文件的断点下载进度，谁来提供？

### Alamfire下载及resumeData

正常下载文件代码： 

```swift
/// 下载的文件地址
let videoURL = "https://dl-android.keepcdn.com/keep-latest_7ee136cd6244b8a53a40ccf373902c55.apk?download/Keep%E7%91%9C%E4%BC%BD%E8%B7%91%E6%AD%A5%E5%81%A5%E8%BA%AB%E9%AA%91%E8%A1%8C%E6%95%99%E7%BB%83-latest.apk"
        let documentURL = FileManager.default.urls(for: .documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
        /// 本地存储的文件路径,当前为了测试，写了固定的文件名: test.apk
        let filePath = documentURL
            .appendingPathComponent("video", isDirectory: true)
            .appendingPathComponent("test.apk")
        
        let localURL = filePath
        
        let destination: DownloadRequest.DownloadFileDestination = { temporaryURL, response in
            
            return (localURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        /// 开始下载文件
        let request =  Alamofire.download(videoURL, to: destination)
            .downloadProgress { (progressObject) in
                print("downloadProgress: \(progressObject)")
            }
            .responseData { (reponseData) in
                switch reponseData.result {
                case .success(let data):
                    print("成功....\(data)")
                case .failure(let error):
                    print("失败....\(error)")
                }
        }
```

使用Alamfire想要实现断点续传，需要在取消或失败的时候保存resumeData，见代码：

```swift
/// 当取消下载或异常停止下载时，会调用response block，在block的response参数中，可以获取到response.resumeData数据，此数据是下载请求的下载信息数据(非真实下载内容)，数据是Plist格式内容
let request =  Alamofire.download(videoURL, to: destination)
            .downloadProgress { (progressObject) in
                print("downloadProgress: \(progressObject)")
            }
            .responseData { (reponseData) in
                switch reponseData.result {
                case .success(let data):
                    print("成功....\(data)")
                case .failure(let error):
                    print("失败....\(error)”)
                    print("失败resumeData.... \(reponseData.resumeData)”)
                    
                    /// resumeData数据的存储路径，当前为了测试，写了固定的文件名: resumeData.tmp
                    let resumeTmpPath = documentURL
                        .appendingPathComponent("cache", isDirectory: true)
                        .appendingPathComponent("resumeData.tmp")
                    if let resumeData = reponseData.resumeData {
                        do {
                            /// 创建缓存目录
                            try FileManager.default.createDirectory(at: documentURL
                                .appendingPathComponent("cache", isDirectory: true), withIntermediateDirectories: true, attributes: nil)
                            
                            /// 判断缓存文件是否存在，存在就删除
                            if FileManager.default.fileExists(atPath: resumeTmpPath.absoluteString) {
                                try FileManager.default.removeItem(at: resumeTmpPath)
                            }
                            /// 写数据到指定本地缓存目录中
                            try resumeData.write(to: resumeTmpPath, options: Data.WritingOptions.atomic)
                            print(":resumeTmpPath: \(resumeTmpPath)")
                        } catch let error {
                            print("error: \(error)")
                        }
                    }
                }
        }
```

### 实现思路

下载失败数据保存: 

```
1.提供一个下载地址和本地存储地址；
2.当取消或下载失败后，从response的block中获取到resumeData数据；
    resumeData不为nil: 继续下一步；
    resumeData为nil: 中止，不继续执行；
3.读取resumeData数据中的NSURLSessionResumeInfoTempFileName该字段获取到临时文件名，去tmp目录查找此文件；
    存在: 读取resumeData中的NSURLSessionResumeBytesReceived字段，判断文件大小与此字段是否一致；
        一致: 文件存在就复制拷贝到Library/Caches目录中备份，根据下载地址做主键或查询条件，并把resumeData数据保存到数据库或Library/Caches目录中；解决了遇到的所有问题；
        不一致: 中止，不继续执行；
    不存在: 中止，不继续执行；
4.到此，可以保存的数据已经完成;
```

继续下载数据恢复或新任务下载:

```
1.提供一个下载地址和本地存储地址；
2.根据下载地址去本地数据库或缓存目录中查找是否有对应的resumeData数据；
    有: 查找resumeData对应的备份缓存文件是否存在及大小的校验；
        存在且可用: 检查tmp目录该缓存文件是否还存在；不存在就拷贝备份缓存文件到tmp目录；存在且可用就不拷贝；
        不存在或不可用: 删除resumeData数据和备份缓存文件，中止，按照新文件第一次下载即可；
    没有: 中止，按照新文件第一次下载即可；
3.调用Alamfire断点续传的接口即可；
4.当再次下载失败时，重复下载失败数据保存的逻辑即可；
5.下载成功，删除之前的对应的resumeData数据和备份缓存文件;
```

数据清理:

```
1.因为每次失败都备份了数据，会导致占用的磁盘内存累积；为了减少内存占用，建议使用以下方式；
2.resumeData使用数据库存储(Realm或CoreData),添加新数据或更新数据时，更新一下此条记录的更新时间；
3.每次打开App后，根据缓存存放的最长时间，比如1周，那么根据更新时间，大于1周的数据全部删除并移除对应的备份缓存文件；也可以根据备份缓存文件的大小，总大小超过一定的阈值后，从更新时间最久的数据开始清理；
4.如果有下载任务管理需求的，就不用做以上缓存清理的工作；
```

### 代码

> 完整代码地址: <https://github.com/coolspan/IOS-AlamfireDownloadResume>

断点续传测试代码:

```swift
let documentURL = FileManager.default.urls(for: .documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
/// resumeData.tmp文件
let resumeTmpPath = documentURL
            .appendingPathComponent("cache", isDirectory: true)
            .appendingPathComponent("resumeData.tmp")
/// 判断文件是否存在
if FileManager.default.fileExists(atPath: resumeTmpPath.path) {
                let filePath = documentURL
                    .appendingPathComponent("video", isDirectory: true)
                    .appendingPathComponent("test.apk")

                let localURL = filePath

                let destination: DownloadRequest.DownloadFileDestination = { temporaryURL, response in
                    return (localURL, [.removePreviousFile, .createIntermediateDirectories])
                }

                let resumeData = try Data.init(contentsOf: resumeTmpPath)
                /// 开始断点续传
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
                            /// 失败之后再次缓存数据
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
} else {
    /// resumeData数据不存在，按照新文件下载吧
}
```

此种方式取消下载不会调用response block：需要使用**<u>downloadRequest.cancel()</u>**方式取消

```swift
Alamofire.SessionManager.default.session.getAllTasks { (tasks) in
            print("全部任务个数:\(tasks.count)")
            for task in tasks {
                task.cancel()
            }
        }
```

### 关于作者

有Android/IOS/小程序、Java/Nodejs等语言的开发经验，有其他问题也可以交流学习，共同进步

如此仓库对你有所帮助，请移动鼠标**Star**一下仓库，你的支持是我源源输出的动力，谢谢您的支持

有好的实现方案，仓库代码会陆续更新，敬请关注；如您有好的方案或建议，也可以邮箱投给我: 965266509@qq.com

公众号: 账号配置中......

## License

    Copyright 2018 coolspan
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    
       http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
