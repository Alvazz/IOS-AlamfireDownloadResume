//
//  DataBaseManager.swift
//  DownloadResume
//
//  Created by 乔晓松 on 2018/8/31.
//  Copyright © 2018年 Coolspan. All rights reserved.
//


import UIKit
import RealmSwift

// Realm数据的封装类
class DataBaseManager {
    
    /* Realm 数据库配置，用于数据库的迭代更新 */
    private static let schemaVersion: UInt64 = 0
    
    //单例
    static let shared = DataBaseManager()
    
    //私有化构造函数
    private init() { }
    
    private lazy var realm = try! Realm()
    
}

// MARK:- public methods
extension DataBaseManager {
    
    // 初始化Realm数据库
    func setup(){
        let config = Realm.Configuration(schemaVersion: DataBaseManager.schemaVersion, migrationBlock: { migration, oldSchemaVersion in
            //什么都不要做！Realm 会自行检测新增和需要移除的属性，然后自动更新硬盘上的数据库架构
            if (oldSchemaVersion < DataBaseManager.schemaVersion) {
                
            }
        })
        Realm.Configuration.defaultConfiguration = config
        Realm.asyncOpen { (realm, error) in
            if let _ = realm {//Realm 成功打开，迁移已在后台线程中完成
                debugPrint("===Realm===> 数据库配置成功")
                debugPrint("===Realm URL===> \(realm?.configuration.fileURL?.absoluteString ?? "")")
            } else if let error = error {//处理打开 Realm 时所发生的错误
                debugPrint("===Realm===> 数据库配置失败：\(error.localizedDescription)")
            }
        }
    }
    
    //添加数据
    func add(object: Object){
        try! realm.write {
            realm.add(object)
        }
    }
    
    //添加多条数据
    func add<Element: Object>(objects: List<Element>){
        try! realm.write {
            realm.add(objects)
        }
    }
    
    //添加对象
    func addInTransaction(object: Object){
        realm.add(object)
    }
    
    //添加对象列表
    func addInTransaction<Element: Object>(objects: List<Element>){
        realm.add(objects)
    }
    
    //删除数据
    func delete(object: Object){
        try! realm.write {
            realm.delete(object)
        }
    }
    
    //删除多条数据
    func delete<Element: Object>(objects: List<Element>){
        try! realm.write {
            realm.delete(objects)
        }
    }
    
    //删除数据库中所有数据
    func clear(){
        try! realm.write {
            realm.deleteAll()
        }
    }
    
    //删除数据库中指定表所有数据
    func clearTable<Element: Object>(objects: List<Element>){
        try! realm.write {
            realm.delete(objects)
        }
    }
    
    //修改数据
    func update<Element: Object>(object: Element, onUpdate: (_ obj: Element) -> ()){
        try! realm.write {
            onUpdate(object)
            realm.add(object, update: true)
        }
    }
    
    //修改数据
    func update(onUpdate: () -> ()){
        try! realm.write {
            onUpdate()
        }
    }
    
    //修改数据
    func updateInTransaction<Element: Object>(object: Element){
        realm.add(object, update: true)
    }
    
    //查询所有数据
    func getAll<Element: Object>(type: Element.Type, onResult: (_ results:Results<Element>) -> ()){
        try! realm.write {
            //realm.objects(type).filter().sorted(byKeyPath: "name", ascending: false)//可以按条件筛选
            onResult(realm.objects(type))
        }
    }
    
    //根据主键查询数据
    func getByPrimaryKey<Element: Object>(type: Element.Type, key:String) -> Element? {
        let ele = realm.object(ofType: type, forPrimaryKey: key)
        return ele
    }
    
    //根据主键查询数据
    func getByPrimaryKey<Element: Object>(type: Element.Type, key:String, onResult: (_ result:Element?) -> ()){
        try! realm.write {
            onResult(realm.object(ofType: type, forPrimaryKey: key))
        }
    }
}
