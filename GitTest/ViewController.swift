//
//  ViewController.swift
//  GitTest
//
//  Created by Administrator on 3/31/18.
//  Copyright © 2018 GitTest. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class HeaderCell: UITableViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    
    fileprivate func config(_ name: String, _ count: Int) {
        nameLabel.text = name
        countLabel.text = "Count: \(count)"
    }
}

class RepoCell: UITableViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var starsLabel: UILabel!
    @IBOutlet weak var forksLabel: UILabel!
    @IBOutlet weak var updatedLabel: UILabel!
    
    fileprivate func config(_ repo: Repo) {
        nameLabel.text = repo.name
        if repo.repoDescription.count > 0 {
            descriptionLabel.text = repo.repoDescription
        } else {
            descriptionLabel.text = "No Description"
        }
        starsLabel.text = "Stars: \(repo.stars)"
        forksLabel.text = "Forks: \(repo.forks)"
        updatedLabel.text = repo.updatedAt.readable
    }
}

class ViewController: UIViewController {
    fileprivate var coordinator: Coordinator?
    fileprivate let bag = DisposeBag()
    fileprivate let searchController = UISearchController(searchResultsController: nil)
    fileprivate var suggestions: [String]? = nil
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var activityBackground: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noResultLabel: UILabel!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    private func searchBarIsEmpty() -> Bool {
        return searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }
    
    fileprivate var isFiltering: Bool {
        return searchController.isActive && !searchBarIsEmpty()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchController.searchBar.delegate = self
        
        searchController.searchBar.scopeButtonTitles = ["Everywhere", "Login", "Email", "Full name"]
        searchController.searchBar.placeholder = "Search Users/Organizations"
        searchController.dimsBackgroundDuringPresentation = false
        navigationItem.searchController = searchController

        searchController.isActive = true
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 160
        
        tableView.sectionHeaderHeight = UITableViewAutomaticDimension
        tableView.estimatedSectionHeaderHeight = 40
        
        activityBackground.layer.cornerRadius = 10
        
        if coordinator == nil {
            coordinator = Coordinator()
            coordinator?.repos.asObservable().observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] (repoList) in
                self?.tableView.reloadData()
                
                if repoList == nil && self?.coordinator?.errorMessage.value == nil {
                    self?.noResultLabel.isHidden = true
                    self?.startLoading()
                } else {
                    self?.stopLoading()
                    
                    if self?.coordinator?.errorMessage.value != nil {
                        self?.noResultLabel.isHidden = false
                    } else {
                        self?.noResultLabel.isHidden = true
                    }
                }
            }).disposed(by: bag)
            
            coordinator?.errorMessage.asObservable().observeOn(MainScheduler.instance).subscribe(onNext: { [unowned self] (errorValue) in
                if let error = errorValue {
                    self.showErrorAlert(error.0, error.1)
                }
            }).disposed(by: bag)
            
            let textObservable = searchController.searchBar.rx.text.orEmpty.distinctUntilChanged().throttle(0.5, scheduler: MainScheduler.instance)
            
            Observable.combineLatest(textObservable, searchController.searchBar.rx.selectedScopeButtonIndex)
                .observeOn(MainScheduler.instance)
                .flatMapLatest { [unowned self] (query, index) -> Single<[String]> in
                    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
                    if query.isEmpty || query.count < 3 {
                        return Single.never()
                    }
                    
                    self.startLoading()
                    
                    guard let searchScope = SearchScope(rawValue: index),
                        let single = self.coordinator?.loadSuggestions(query, searchScope) else {
                        return Single.never()
                    }
                    return single
                }
                .subscribe(onNext: { [weak self] (list) in
                    self?.stopLoading()
                    
                    self?.suggestions = list
                    self?.tableView.reloadData()
                }, onError: { [weak self] (error) in
                    self?.stopLoading()
                }).disposed(by: bag)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchController.isActive = true
    }
    
    fileprivate func startLoading() {
        activityIndicator.startAnimating()
        activityBackground.isHidden = false
    }
    
    fileprivate func stopLoading() {
        activityIndicator.stopAnimating()
        activityBackground.isHidden = true
    }
    
    fileprivate func getRepos(for username: String) {
        searchController.isActive = false
        tableView.reloadData()
        navigationItem.title = "Search for: \(username)"
        
        coordinator?.load(username: username)
    }
    
    fileprivate func showErrorAlert(_ title: String, _ message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(.init(title: "Ok", style: .default, handler: nil))
        self.present(alertController, animated: true)
    }
}

extension ViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let search = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines), search.count > 0 else { return }
        
        getRepos(for: search)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchController.isActive = false
        tableView.reloadData()
    }
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        
    }
}

extension ViewController: UITableViewDelegate {
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        if isFiltering {
            return nil
        } else {
            let short = coordinator?.sortedLanguages().map { String($0.prefix(5)) }
            return short
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchController.searchBar.endEditing(false)
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isFiltering {
            guard let username = suggestions?[indexPath.row] else { return }
            getRepos(for: username)
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerCell = tableView.dequeueReusableCell(withIdentifier: "headercell") as! HeaderCell
        
        if let count = suggestions?.count, isFiltering {
            headerCell.config("Suggestions", count)
        } else if let language = coordinator?.sortedLanguages()[section],
            let count = coordinator?.repos.value?[section].count {
            headerCell.config(language, count)
        }
        
        return headerCell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if isFiltering {
            return 1
        } else {
            guard let count = coordinator?.repos.value?.count else { return 0 }
            return count
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isFiltering {
            guard let count = suggestions?.count else { return 0 }
            return count
        } else {
            guard let count = coordinator?.repos.value?[section].count else { return 0 }
            return count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isFiltering {
            let cell = tableView.dequeueReusableCell(withIdentifier: "searchcell")!
            
            if let text = suggestions?[indexPath.row] {
                cell.textLabel?.text = text
            }
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "gitcell") as! RepoCell
            
            if let repo = coordinator?.repos.value?[indexPath.section][indexPath.row] {
                cell.config(repo)
            }
            
            return cell
        }
    }
}
