//
//  NetworkService.swift
//  GitTest
//
//  Created by Administrator on 3/31/18.
//  Copyright © 2018 GitTest. All rights reserved.
//

import Foundation
import RxSwift

protocol NetworkServiceDelegate {
    func loaded(json: [[String: Any?]])
}

enum UserType: String {
    case user = "users"
    case organization = "orgs"
}

enum ErrorMessage {
    case noResult, noData, unknown, networkError(String)
}

enum NetworkState {
    case loading, loaded, error(ErrorMessage)
}

class NetworkService {
    let oauthService: AuthorizationService
    var delegate: NetworkServiceDelegate?
    
    let state = Variable<NetworkState>(.loaded)
    
    fileprivate let bag = DisposeBag()
    
    init(delegate: NetworkServiceDelegate? = nil) {
        self.oauthService = AuthorizationService()
        self.delegate = delegate
    }
    
    func load(username: String) {
        state.value = .loading
        getData(username: username, currentPage: 0)
    }
    
    fileprivate func getData(username: String, userType: UserType = .organization, currentPage: Int) {
        let urlString: String
        urlString = "https://api.github.com/\(userType.rawValue)/\(username)/repos?per_page=100&page=\(currentPage)&client_id=\(self.oauthService.clientId)&client_secret=\(self.oauthService.clientSecret)"
        
        guard let url = URL(string: urlString) else { return }
        
        get(url: url, complition: { [unowned self] (data, response) in
            guard let responseData = data else {
                    self.state.value = .error(.noData)
                    return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.state.value = .error(.unknown)
                return
            }
            
            let code = httpResponse.statusCode
            
            guard code == 200 else {
                if code == 404 {
                    self.state.value = .error(.noResult)
                } else {
                    self.state.value = .error(.unknown)
                }
                return
            }
            
            guard let jsonOptional = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [[String: Any?]], let json = jsonOptional else {
                if userType == .organization && currentPage == 0 {
                    self.getData(username: username, userType: .user, currentPage: 0)
                } else {
                    self.state.value = .error(.unknown)
                }
                
                return
            }

            self.delegate?.loaded(json: json)
            if json.count == 100 {
                self.getData(username: username, currentPage: currentPage + 1)
            } else {
                self.state.value = .loaded
            }
        }, failure: { [unowned self] (error) in
            let errorString = error.localizedDescription
            self.state.value = .error(.networkError(errorString))
        })
    }
    
    fileprivate func get(url: URL, complition: @escaping (Data?, URLResponse?) -> Void, failure: @escaping (Error) -> Void) {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 300)
        let session = URLSession(configuration: .default)
        session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                failure(error)
            } else {
                complition(data, response)
            }
        }.resume()
    }
}
