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
    
    fileprivate var models: [String: Results<Repo>] = [:]

    let repos = Variable<[Results<Repo>]?>([])

    init() {
        networkService = NetworkService()
        networkService.delegate = self
        networkService.state.asObservable().subscribe(onNext: { [unowned self] (result) in
            DispatchQueue.main.async {
                if result == .loaded || result == .error {
                    self.models = self.database.get(username: self.currentSearch)
                    self.repos.value = self.models.values.sorted(by: { $0.count > $1.count })
                } else {
                    self.repos.value = nil
                }
            }
        }).disposed(by: bag)
    }

    func load(username: String) {
        currentSearch = username
        models.removeAll()
        networkService.load(username: currentSearch)
    }
    
    func sortedLanguages() -> [String] {
        return models.sorted { $0.value.count > $1.value.count }.map { $0.key }
    }
}

extension Coordinator: NetworkServiceDelegate {
    func loaded(json: [[String : Any?]]) {
        database.create(jsonArray: json)
    }
}
