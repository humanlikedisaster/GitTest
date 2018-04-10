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

enum Response {
    case dictionary([String: Any?])
    case array([[String: Any?]])
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
    let host = "https://api.github.com/"
    
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
        getData(username: username, currentPage: 1)
    }
    
    func searchUser(username: String, completion: @escaping ([String]) -> Void, failure: @escaping () -> Void) {
        let urlString: String
        urlString = "\(host)search/users?q=\(username)+in:login&client_id=\(self.oauthService.clientId)&client_secret=\(self.oauthService.clientSecret)"
        guard let url = URL(string: urlString) else { return }
        
        getWrapped(url: url, completion: { (response) in
            switch response {
            case .array(_): failure()
            case .dictionary(let json):
                guard let items = json["items"] as? [[String: Any?]] else { return }
                
                var list: [String] = []
                
                for item in items {
                    if let login = item["login"] as? String {
                        list.append(login)
                    }
                }
                
                completion(list)
            }
        }) { (error) in
            failure()
        }
    }
    
    fileprivate func getData(username: String, userType: UserType = .organization, currentPage: Int) {
        let urlString: String
        urlString = "\(host)\(userType.rawValue)/\(username)/repos?per_page=100&page=\(currentPage)&client_id=\(self.oauthService.clientId)&client_secret=\(self.oauthService.clientSecret)"
        
        guard let url = URL(string: urlString) else { return }
        
        getWrapped(url: url, completion: { (response) in
            switch response {
            case .array(let json):
                self.delegate?.loaded(json: json)
                
                if json.count == 100 {
                    self.getData(username: username, userType: userType, currentPage: currentPage + 1)
                } else {
                    self.state.value = .loaded
                }
            case .dictionary(_):
                self.state.value = .error(.unknown)
            }
        }) { (error) in
            switch error {
            case .noResult:
                if userType == .organization && currentPage == 1 {
                    self.getData(username: username, userType: .user, currentPage: 1)
                } else {
                    self.state.value = .error(error)
                }
            default: self.state.value = .error(error)
            }
            
        }
    }
    
    fileprivate func getWrapped(url: URL, completion: @escaping (Response) -> Void, failure: @escaping (ErrorMessage) -> Void) {
        get(url: url, completion: { (data, response) in
            guard let responseData = data else {
                failure(.noData)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                failure(.unknown)
                return
            }
            
            let code = httpResponse.statusCode
            
            guard code == 200 else {
                if code == 404 {
                    failure(.noResult)
                } else {
                    failure(.unknown)
                }
                return
            }
            
            guard let jsonArray = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [[String: Any?]], let jsonArr = jsonArray else {
                guard let jsonOptional = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any?], let json = jsonOptional else {
                    failure(.unknown)
                    return
                }
                completion(.dictionary(json))
                return
            }
            completion(.array(jsonArr))
        }, failure: { (error) in
                let errorString = error.localizedDescription
                failure(.networkError(errorString))
        })
    }
    
    fileprivate func get(url: URL, completion: @escaping (Data?, URLResponse?) -> Void, failure: @escaping (Error) -> Void) {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 300)
        let session = URLSession(configuration: .default)
        session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                failure(error)
            } else {
                completion(data, response)
            }
        }.resume()
    }
}
