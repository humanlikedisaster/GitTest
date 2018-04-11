//
//  Coordinator.swift
//  GitTest
//
//  Created by Administrator on 4/1/18.
//  Copyright © 2018 GitTest. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import RealmSwift

enum SearchScope: Int {
    case all = 0, login, email, fullname
    
    func query() -> String {
        switch self {
        case .all:
            return ""
        case .login:
            return "+in:login"
        case .email:
            return "+in:email"
        case .fullname:
            return "+in:fullname"
        }
    }
}

class Coordinator {
    fileprivate let database = Database()
    fileprivate let networkService = NetworkService()
    fileprivate var bag = DisposeBag()
    fileprivate var currentLoad: Observable<NetworkState>?
    
    fileprivate var languages: [String] = []
    
    let errorMessage = Variable<(String, String)?>(nil)
    let repos = Variable<[Results<Repo>]?>([])
    
    func loadSuggestions(_ username: String, _ searchScope: SearchScope) -> Single<[String]> {
        return Single<[String]>.create(subscribe: { [weak self] (single) -> Disposable in
            self?.networkService.searchUser(username: username, searchScope: searchScope, completion: { (list) in
                single(.success(list))
            }, failure: {
                single(.error(NSError(domain: "Suggestion", code: 100, userInfo: nil)))
            })

            return Disposables.create {  }
        }).observeOn(MainScheduler.instance)
    }

    func load(username: String) {
        errorMessage.value = nil
        languages.removeAll()
        self.repos.value = nil
        bag = DisposeBag()
        currentLoad = networkService.load(username: username).observeOn(MainScheduler.instance).share()

        guard let currentLoad = currentLoad else { return }

        currentLoad.subscribe(onNext: { [unowned self] result in
            switch result {
            case .error(let errorMessage):
                switch errorMessage {
                case .networkError(let errorString):
                    self.loadFromDatabase(username)
                    if self.languages.count == 0 {
                        self.errorMessage.value = ("Network error", errorString)
                    }
                case .noData, .unknown:
                    self.loadFromDatabase(username)
                    self.errorMessage.value = ("Unknown error", "Unknown error was occured!")
                case .noResult:
                    self.errorMessage.value = ("Nothing found", "There is no such user or organization.")
                    self.repos.value = nil
                }
            case .loading(let json): self.database.create(jsonArray: json)
            }
        }).disposed(by: bag)
        
        currentLoad.toArray().flatMapLatest {
            [unowned self] _ in return self.database.databaseUpdates
        }.subscribe(onNext: { () in
            self.loadFromDatabase(username)
        }).disposed(by: bag)
    }
    
    fileprivate func loadFromDatabase(_ username: String) {
        let models = self.database.get(username: username).sorted { $0.value.count > $1.value.count }
        self.languages = models.map { $0.key }
        self.repos.value = models.map { $0.value }
    }
    
    func sortedLanguages() -> [String] {
        return languages
    }
}
