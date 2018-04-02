//
//  Coordinator.swift
//  GitTest
//
//  Created by Administrator on 4/1/18.
//  Copyright © 2018 GitTest. All rights reserved.
//

import Foundation
import RxSwift
import RealmSwift

class Coordinator {
    fileprivate var currentSearch: String = ""
    fileprivate let database = Database()
    fileprivate let networkService: NetworkService
    fileprivate let bag = DisposeBag()
    
    fileprivate var languages: [String] = []

    let errorMessage = Variable<(String, String)?>(nil)
    let repos = Variable<[Results<Repo>]?>([])

    init() {
        networkService = NetworkService()
        
        database.delegate = self
        
        networkService.delegate = self
        networkService.state.asObservable().subscribe(onNext: { [unowned self] (result) in
            DispatchQueue.main.async {
                switch result {
                case .loaded:
                    break
                case .error(let errorMessage):
                    switch errorMessage {
                    case .networkError(let errorString):
                        self.loadFromDatabase()
                        if self.languages.count == 0 {
                            self.errorMessage.value = ("Network error", errorString)
                        }
                    case .noData, .unknown:
                        self.loadFromDatabase()
                        self.errorMessage.value = ("Unknown error", "Unknown error was occured!")
                    case .noResult:
                        self.errorMessage.value = ("Nothing found", "There is no such user or organization.")
                        self.repos.value = nil
                    }
                case .loading: self.repos.value = nil
                }
            }
        }).disposed(by: bag)
    }

    func load(username: String) {
        errorMessage.value = nil
        currentSearch = username
        languages.removeAll()
        networkService.load(username: currentSearch)
    }
    
    fileprivate func loadFromDatabase() {
        let models = self.database.get(username: self.currentSearch).sorted { $0.value.count > $1.value.count }
        self.languages = models.map { $0.key }
        self.repos.value = models.map { $0.value }
    }
    
    func sortedLanguages() -> [String] {
        return languages
    }
}

extension Coordinator: DatabaseDelegate {
    func databaseUpdated() {
        switch networkService.state.value {
        case .loaded:
            self.loadFromDatabase()
        default: break
        }
    }
}

extension Coordinator: NetworkServiceDelegate {
    func loaded(json: [[String : Any?]]) {
        DispatchQueue.global().async {
            self.database.create(jsonArray: json)
        }
    }
}
