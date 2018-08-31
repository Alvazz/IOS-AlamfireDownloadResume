//
//  RealmTool.swift
//  DownloadResume
//
//  Created by 乔晓松 on 2018/8/31.
//  Copyright © 2018年 Coolspan. All rights reserved.
//

import RealmSwift

public class RealmTool {
    
    /// 数据库是否加密
    private static var encryption = false
    
    /// 加密的秘钥，只有当需要加密的时候才使用
    private static var encryptionKey: Data?
    
    /// 在当前调用线程，创建一个写入事务,并在闭包中将创建的Realm对象传出，以供闭包中使用
    /// 如果RealmTool封装的方法不能满足需求时，可以利用此方法，实现更多没有封装的自定义的逻辑。
    ///
    /// 注意：
    ///
    /// 1、如果抛出异常，事物将被取消，前面所做的所有改变将会回退
    ///
    /// 2、一个Realm数据库文件同时只能有一个写入事务，并且事务不可嵌套
    ///
    /// 3、由于并且事务不可嵌套，所以在closure中不能够直接调用RealmTool中封装的增、删、改相关的方法
    ///
    /// - Parameter closure: 业务逻辑闭包
    public static func write(_ closure: @escaping (Realm)->()) {
        guard let realm = getRealm() else {
            return
        }
        do {
            try realm.write {
                closure(realm)
            }
        } catch let error {
            DDLogDebug("写入事务执行失败:\n\(error.localizedDescription)")
        }
    }
    
    /// 根据传入的Realm队形，创建一个写入事务，并在事务中执行闭包
    /// 如果RealmTool封装的方法不能满足需求时，可以利用此方法，实现更多没有封装的自定义的逻辑。
    ///
    /// 注意：
    ///
    /// 1、如果抛出异常，事物将被取消，前面所做的所有改变将会回退
    ///
    /// 2、一个Realm数据库文件同时只能有一个写入事务，并且事务不可嵌套
    ///
    /// 3、由于并且事务不可嵌套，所以在closure中不能够直接调用RealmTool中封装的增、删、改相关的方法
    ///
    /// 4、传入的realm对象不能跨线程
    ///
    /// - Parameters:
    ///   - realm: Realm对象
    ///   - closure: 业务逻辑闭包
    public static func write( realm: Realm?, _ closure: @escaping ()->()) {
        guard let realm = realm else {
            DDLogDebug("传入的realm对象为nil")
            return
        }
        do {
            try realm.write {
                closure()
            }
        } catch let error {
            DDLogDebug("写入事务执行失败:\n\(error.localizedDescription)")
        }
    }
    
    /// 获取当前打开的数据库实例对象
    ///
    /// - Parameter result: 或缺realm对象的结果闭包
    /// - Returns: 返回当前打开的数据库实例
    public static func getRealm(_ result: ((Error?) -> Void)? = nil) -> Realm? {
        do {
            if encryption {
                let config = Realm.Configuration(encryptionKey: encryptionKey)
                return try Realm(configuration: config)
            } else {
                return try Realm()
            }
        } catch let error {
            DDLogDebug("获取当前的Realm的数据库失败:\n\(error.localizedDescription)")
            result?(error)
            return nil
        }
    }
    
    /// 禁止被实例化
    private init() {}
}

// MARK: - 初始化数据库
public extension RealmTool {
    
    /// 打开数据库
    ///
    /// - Parameter dataBaseName: 数据库名称
    static func openRealm(dataBaseName: String) {
        initRealm(dataBaseName: dataBaseName)
    }
    
    /// 打开数据库，并需要做数据迁移
    ///
    /// - Parameters:
    ///   - dataBaseName: 数据库名称
    ///   - version: 版本号,指定的版本号必须大于等于原来的版本号，系统最初默认的版本号为0
    ///   - migrationBlock: 数据迁移的闭包，将数据迁移的逻辑写在此闭包中
    static func openRealm(dataBaseName: String, version: UInt64, _ migrationBlock:  @escaping MigrationBlock) {
        initRealm(dataBaseName: dataBaseName, version: version, migrationBlock)
    }
    
    /// 初始化(创建/打开)数据库, 一旦用此方法初始化之后，系统默认的数据库就是这个数据库了，以后使用
    /// RealmTool.getRealm()方法获取到的Realm对象就是指向这个数据库的。如果想要切换数据库，只需
    /// 要再次调用此方法，传入相应的参数即可切换系统默认的数据库到指定的数据库。
    /// 提示：由于参数很多，有默认值的参数，可根据需要，选择性的传入。
    ///
    /// - Parameters:
    ///   - dataBaseName: 自定义的数据库名称
    ///   - readOnly: 是否只读,默认为false，一般打开预植数据库时设置为true
    ///   - reference: 是否是打开预植数据库，默认为false
    ///   - encryption: 数据库是否加密，默认为false
    ///   - encryptionKey: 加密的秘钥，在encryption为true时，必须传此参数
    ///   - version: 版本号，默认为0. 只有在需要做数据迁移的时候主动设置为最新的版本号
    ///   - migrationBlock: 数据迁移的闭包，将数据迁移的逻辑写在此闭包中，使用时，必须指定版本号
    static func initRealm(dataBaseName: String, readOnly: Bool = false, reference: Bool = false, encryption: Bool = false, encryptionKey: Data? = nil, version: UInt64 = 0, _ migrationBlock: MigrationBlock? = nil) {
        // 获取数据库路径
        guard let dataBasePath = reference ? getReferenceDatabasePaeh(dataBaseName) : getCreatDatabasePath(dataBaseName) else {
            return
        }
        self.encryption = encryption
        var config = Realm.Configuration()
        if encryption {
            self.encryptionKey = encryptionKey
            config = Realm.Configuration(encryptionKey: encryptionKey)
        }
        config.fileURL = dataBasePath
        config.readOnly = readOnly
        config.schemaVersion = version
        config.migrationBlock = migrationBlock
        Realm.Configuration.defaultConfiguration = config
    }
}

// MARK: - 添加
public extension RealmTool {
    
    /// 添加或更新一个对象
    ///
    /// 注意：
    ///
    /// 1、只有有主键的对象才可以将update对象设置为true，否则将会报错；
    ///
    /// 2、有主键的对象，update设置为false时，如果数据库中已经存在此对象，会报错
    ///
    /// 3、如果添加的对象是其他Realm数据库持有处理的对象，应该使用creat(_ type:, value:, update:)
    ///
    /// - Parameters:
    ///   - object: 待添加或更新的对象
    ///   - update: 是否更新，默认为false
    static func add<T: Object>(_ object: T, update: Bool = false) {
        write { $0.add(object, update: update) }
    }
    
    /// 添加或更新一组对象
    ///
    /// 注意：
    ///
    /// 1、只有有主键的对象才可以将update对象设置为true，否则将会报错；
    ///
    /// 2、有主键的对象，update设置为false时，如果数据库中已经存在此对象，会报错
    ///
    /// 3、如果添加的对象是其他Realm数据库持有处理的对象，应该使用creat(_ type:, value:, update:)
    ///
    /// - Parameters:
    ///   - objects: 待添加或更新的对象
    ///   - update: 是否更新，默认为false
    static func add<S: Sequence>(_ objects: S, update: Bool = false) where S.Iterator.Element: Object {
        write { $0.add(objects, update: update) }
    }
    
    /// 添加(创建)或更新一个对象
    ///
    /// 注意：
    ///
    /// 1、如果添加的对象是其他Realm数据库持有处理的对象，只能使用此方法，不能使用add
    ///
    /// 2、只有有主键的对象才可以将update对象设置为true，否则将会报错；
    ///
    /// 3、有主键的对象，update设置为false时，如果数据库中已经存在此对象，会报错
    ///
    /// - Parameters:
    ///   - type: 对象类型
    ///   - value: 对象的值
    ///   - update: 是否更新，默认为false
    static func creat<T: Object>(_ type: T.Type, value: Any, update: Bool = false) {
        write { $0.create(type, value: value, update: update) }
    }
}

// MARK: - 删除
public extension RealmTool {
    
    /// 删除传入类型的表中所有对象
    ///
    /// - Parameter type: 要删除的对象类型(表)
    static func delete<T: Object>(_ type: T.Type) {
        write { $0.delete($0.objects(type)) }
    }
    
    /// 删除传入类型的表中指定主键对应的对象
    ///
    /// - Parameters:
    ///   - type: 要删除的对象类型(表)
    ///   - primaryKey: 主键
    static func delete<T: Object>(_ type: T.Type, primaryKey: Any) {
        write {
            guard let obj = $0.object(ofType: type, forPrimaryKey: primaryKey) else {
                DDLogDebug("删除的对象不存在")
                return
            }
            $0.delete(obj)
        }
    }
    
    /// 删除传入类型的表中断言过滤出的对象
    ///
    /// - Parameters:
    ///   - type: 要删除的对象类型(表)
    ///   - filter: 断言字符串
    static func delete<T: Object>(_ type: T.Type, filter: String) {
        write { $0.delete($0.objects(type).filter(filter))}
    }
    
    /// 删除传入类型的表中谓词筛选出的对象
    ///
    /// - Parameters:
    ///   - type: 要删除的对象类型(表)
    ///   - predicate: 谓词对象
    static func delete<T: Object>(_ type: T.Type,  predicate: NSPredicate) {
        write { $0.delete($0.objects(type).filter(predicate)) }
    }
    
    /// 删除单个对象
    ///
    /// - Parameter object: 要删除的对象
    static func delete<T: Object>(_ object: T?) {
        guard let object = object else {
            DDLogDebug("待删除的对象为nil")
            return
        }
        write { $0.delete(object) }
    }
    
    /// 删除对象数组
    ///
    /// - Parameter objects: 要删除的[T]对象
    static func delete<T: Object>(_ objects: [T]?) {
        guard let objects = objects else {
            DDLogDebug("待删除的对象为nil")
            return
        }
        write { $0.delete(objects) }
    }
    
    /// 删除List<Object>
    ///
    /// - Parameter objects: 要删除的List<T>对象
    static func delete<T: Object>(_ objects: List<T>?) {
        guard let objects = objects else {
            DDLogDebug("待删除的对象为nil")
            return
        }
        write { $0.delete(objects) }
    }
    
    /// 删除Results<T>
    ///
    /// - Parameter objects: 要删除的Results<T>对象
    static func delete<T: Object>(_ objects: Results<T>?) {
        guard let objects = objects else {
            DDLogDebug("待删除的对象为nil")
            return
        }
        write { $0.delete(objects) }
    }
    
    /// 删除当前数据库中所有对象(所有表中的数据)
    ///
    /// 注意：删除后文件依然存在，表结构依然存在
    static func deleteAll() {
        write { $0.deleteAll() }
    }
    
    @discardableResult
    /// 删除当前打开的数据库（文件不再存在）
    ///
    /// 注意：删除后数据库相关的文件都不再存在，表结构就更没有了
    /// - Returns: 是否成功
    static func deleteDataBase() -> Bool {
        
        return  autoreleasepool { () -> Bool in
            let realmURL = Realm.Configuration.defaultConfiguration.fileURL!
            let realmURLs = [
                realmURL,
                realmURL.appendingPathExtension("lock"),
                realmURL.appendingPathExtension("management")
            ]
            for URL in realmURLs {
                do {
                    try FileManager.default.removeItem(at: URL)
                } catch {
                    // 错误处理
                    DDLogDebug("删除数据库文件失败\(URL.absoluteString)")
                    return false
                }
            }
            return true
        }
    }
}

// MARK: - 修改
public extension RealmTool {
    
    /// 更新表中的所有对象或某一个对象的某一个字段，为指定的值
    ///
    /// - Parameters:
    ///   - type: 更行的对象类型(表)
    ///   - key: 待更新的字段
    ///   - value: 新的值
    ///   - primaryKey: 主键，默认为空，更新表中所有的对象；如果指定了主键，则只更新一个对象
    static func update<T: Object>(_ type: T.Type, key: String, value: Any, primaryKey: Any? = nil) {
        write {
            let objects = primaryKey == nil ? $0.objects(type) : $0.object(ofType: type, forPrimaryKey: primaryKey)
            objects?.setValue(value, forKeyPath: key)
        }
    }
    
    /// 更新表中的指定对象的某一个字段，为指定的值
    ///
    /// - Parameters:
    ///   - type: 更行的对象类型(表)
    ///   - key: 待更新的字段
    ///   - value: 新的值
    ///   - filter: 断言字符串
    static func update<T: Object>(_ type: T.Type, key: String, value: Any, filter: String) {
        write {
            let objects = $0.objects(type).filter(filter)
            objects.setValue(value, forKeyPath: key)
        }
    }
    
    /// 更新表中的指定对象的某一个字段，为指定的值
    ///
    /// - Parameters:
    ///   - type: 更行的对象类型(表)
    ///   - key: 待更新的字段
    ///   - value: 新的值
    ///   - predicate: 谓词对象
    static func update<T: Object>(_ type: T.Type, key: String, value: Any, predicate: NSPredicate) {
        write {
            let objects = $0.objects(type).filter(predicate)
            objects.setValue(value, forKeyPath: key)
        }
    }
    
}

// MARK: - 查找
public extension RealmTool {
    
    /// 查询一个表中的所有数据
    ///
    /// - Parameter type: 对象类型(表)
    /// - Returns: Results<T>? 对象(相当于一个数组)
    static func getObjects<T: Object>(_ type: T.Type) -> Results<T>? {
        return getRealm()?.objects(type)
    }
    
    /// 根据主键查找某个对象
    ///
    /// - Parameters:
    ///   - type: 对象类型(表)
    ///   - primaryKey: 主键
    /// - Returns: 查找到的对象
    static func getObject<T: Object>(_ type: T.Type, primaryKey: Any) -> T? {
        return getRealm()?.object(ofType: type, forPrimaryKey: primaryKey)
    }
    
    /// 使用断言进行查询
    ///
    /// - Parameters:
    ///   - type: 对象类型(表)
    ///   - filter: 断言字符串
    /// - Returns: 查找到的对象
    static func getObjects<T: Object>(_ type: T.Type, filter: String) -> Results<T>? {
        return getObjects(type)?.filter(filter)
    }
    
    /// 使用谓词进行查询
    ///
    /// - Parameters:
    ///   - type: 对象类型(表)
    ///   - predicate: 谓词对象
    /// - Returns: 查找到的对象
    static func getObjects<T: Object>(_ type: T.Type,  predicate: NSPredicate) -> Results<T>? {
        return getObjects(type)?.filter(predicate)
    }
}

// MARK: - 静态私有方法
private extension RealmTool {
    
    /// 在创建数据库的时候要保存的数据库路径, 保存在Document文件中的DB目录下
    ///
    /// - Parameter fileName: 数据库名字
    /// - Returns: 数据库保存的路径
    static func getCreatDatabasePath(_ fileName: String) -> URL? {
        let cachesPaeh = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        guard var filePath = cachesPaeh else {
            return nil
        }
        filePath = filePath + "/DB/\(fileName)"
        do {
            if !FileManager.default.fileExists(atPath: filePath) {
                try FileManager.default.createDirectory(atPath: filePath, withIntermediateDirectories: true, attributes: nil)
            }
        } catch let error {
            DDLogDebug("创建数据库文件夹:\(error.localizedDescription)")
            return nil
        }
        let path = filePath + "/\(fileName).realm"
        DDLogDebug(path)
        return URL.init(string: path)
    }
    
    /// 获取预植数据库的路径
    ///
    /// - Parameter fileName: 数据库的名字
    /// - Returns: 本地引用的数据库的路径
    static func getReferenceDatabasePaeh(_ fileName: String) -> URL? {
        let path = Bundle.main.path(forResource: fileName, ofType: "realm")
        let url = path != nil ? URL.init(string: path!) : nil
        return url
    }
    
}

func DDLogDebug<T>(_ message : T, file : String = #file, lineNumber : Int = #line) {
    
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    //    print("[\(fileName):line:\(lineNumber)]- \(message)")
    NSLog("[\(fileName):line:\(lineNumber)]- \(message)")
    #endif
}
