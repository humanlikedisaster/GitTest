//
//  ViewController.swift
//  GitTest
//
//  Created by Administrator on 3/31/18.
//  Copyright © 2018 GitTest. All rights reserved.
//

import UIKit
import RxSwift

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
    var coordinator: Coordinator?
    let bag = DisposeBag()
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var activityBackground: UIView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 160
        
        tableView.sectionHeaderHeight = UITableViewAutomaticDimension
        tableView.estimatedSectionHeaderHeight = 40
        
        activityBackground.layer.cornerRadius = 10
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if coordinator == nil {
            coordinator = Coordinator()
            coordinator?.repos.asObservable().subscribe(onNext: { [weak self] (repoList) in
                self?.tableView.reloadData()
                
                if repoList == nil {
                    self?.activityIndicator.startAnimating()
                    self?.activityBackground.isHidden = false
                } else {
                    self?.activityIndicator.stopAnimating()
                    self?.activityBackground.isHidden = true
                }
            }).disposed(by: bag)
        }
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,  let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? Double,
            let curve = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? UInt else { return }
        let keyboardHeight = (userInfo[UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue.size.height
        bottomConstraint.constant = keyboardHeight
        UIView.animate(withDuration: duration, delay: 0, options: UIViewAnimationOptions(rawValue: curve), animations: { () -> Void in
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
            let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? Double,
            let curve = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? UInt else { return }
        bottomConstraint.constant = 0.0
        
        UIView.animate(withDuration: duration, delay: 0, options: UIViewAnimationOptions(rawValue: curve), animations: { () -> Void in
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
}

extension ViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let search = searchBar.text else { return }
        searchBar.endEditing(false)
        coordinator?.load(username: search)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(false)
    }
}

extension ViewController: UITableViewDelegate {
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        let short = coordinator?.sortedLanguages().map { String($0.prefix(5)) }
        return short
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchBar.endEditing(false)
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerCell = tableView.dequeueReusableCell(withIdentifier: "headercell") as! HeaderCell
        
        if let language = coordinator?.sortedLanguages()[section],
            let count = coordinator?.repos.value?[section].count {
            headerCell.config(language, count)
        }
        
        return headerCell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let language = coordinator?.sortedLanguages()[section] else { return "" }
        return language
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        guard let count = coordinator?.repos.value?.count else { return 0 }
        return count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let count = coordinator?.repos.value?[section].count else { return 0 }
        return count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "gitcell") as! RepoCell
        
        if let repo = coordinator?.repos.value?[indexPath.section][indexPath.row] {
            cell.config(repo)
        }
        
        return cell
    }
}
