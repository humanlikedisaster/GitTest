//
//  Database.swift
//  GitTest
//
//  Created by Administrator on 4/1/18.
//  Copyright © 2018 GitTest. All rights reserved.
//

import Foundation
import RealmSwift
import RxSwift

extension Formatter {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

extension Date {
    var readable: String {
        return DateFormatter.localizedString(from: self, dateStyle: .medium, timeStyle: .short)
    }
    
    var iso8601: String {
        return Formatter.iso8601.string(from: self)
    }
}

extension String {
    var dateFromISO8601: Date? {
        return Formatter.iso8601.date(from: self) 
    }
}

class Repo: Object {
    @objc dynamic var id = 0
    @objc dynamic var name = ""
    @objc dynamic var repoDescription = ""
    @objc dynamic var stars = 0
    @objc dynamic var forks = 0
    @objc dynamic var updatedAt = Date(timeIntervalSince1970: 1)
    @objc dynamic var language = "No language"
    @objc dynamic var owner = ""
    
    override static func primaryKey() -> String? {
        return "id"
    }
}

class Database {
    func create(jsonArray: [[String: Any?]]) {
        var batchArray: [Repo] = []
        for json in jsonArray {
            if let owner = json["owner"] as? [String: Any?],
                let id = json["id"] as? Int,
                let name = json["name"] as? String,
                let stars = json["stargazers_count"] as? Int,
                let forks = json["forks_count"] as? Int,
                let login = owner["login"] as? String,
                let updated = json["updated_at"] as? String {
                
                let repo = Repo()
                
                repo.id = id
                repo.name = name
                repo.stars = stars
                repo.forks = forks
                repo.owner = login.uppercased()
                
                if let date = updated.dateFromISO8601 {
                    repo.updatedAt = date
                }
                
                if let language = json["language"] as? String {
                    repo.language = language
                }
                
                if let description = json["description"] as? String {
                    repo.repoDescription = description
                }
                
                batchArray.append(repo)
            }
        }
        
        let realm = try! Realm()
        
        try! realm.write {
            realm.add(batchArray, update: true)
        }
    }
    
    func get(username: String) -> [String: Results<Repo>] {        
        var result: [String: Results<Repo>] = [:]
        
        let realm = try! Realm()
        
        let fullList = realm.objects(Repo.self).filter("owner == \'\(username.uppercased())\'")
        let list = Set(fullList.map { $0.language })
        
        for language in list {
            let list = realm.objects(Repo.self).filter("language == \'\(language)\' AND owner == \'\(username.uppercased())\'").sorted(byKeyPath: "stars", ascending: false)
            result[language] = list
        }
        
        return result
    }
}
