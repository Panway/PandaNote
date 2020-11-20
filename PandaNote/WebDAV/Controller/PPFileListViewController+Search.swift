//
//  PPFileListViewController+Search.swift
//  PandaNote
//
//  Created by topcheer on 2020/11/20.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import Foundation



extension PPFileListViewController {
    //设置搜索控制器
    func setupSearchController() {
        resultsTableController = PPResultsTableController()
        // This view controller is interested in table view row selections.
        resultsTableController.tableView.delegate = self
        
        searchController = UISearchController(searchResultsController: resultsTableController)
        searchController.delegate = self
//        searchController.searchResultsUpdater = self
        searchController.searchBar.autocapitalizationType = .none
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self // Monitor when the search button is tapped.
        
//        searchController.searchBar.scopeButtonTitles = ["A","B","C","D"]

        
        if #available(iOS 11.0, *) {
            // 将搜索栏放置在导航栏中 Place the search bar in the navigation bar.
            navigationItem.searchController = searchController
            // 滚动时隐藏搜索栏
            navigationItem.hidesSearchBarWhenScrolling = true
        } else {
            // Fallback on earlier versions
        }
        
        definesPresentationContext = true
    }
}

// MARK: - UISearchBarDelegate

extension PPFileListViewController: UISearchBarDelegate {
    // 键盘的搜索按钮点击后
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        PPFileManager.shared.searchFileViaWebDAV(path: self.pathStr, searchText: searchBar.text) { (files, isF, error) in
//            let _ = files.map {
//                debugPrint($0.name)
//            }

            if let resultsController = self.searchController.searchResultsController as? PPResultsTableController {
                resultsController.filteredProducts = files
                resultsController.tableView.reloadData()
            }
        }
    }
    // 搜索框下面的类型按钮点击后
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
//        updateSearchResults(for: searchController)
    }
    
}

// MARK: - UISearchControllerDelegate

// Use these delegate functions for additional control over the search controller.

extension PPFileListViewController: UISearchControllerDelegate {
    
    func presentSearchController(_ searchController: UISearchController) {
        Swift.debugPrint("UISearchControllerDelegate invoked method: \(#function).")
    }
    
    func willPresentSearchController(_ searchController: UISearchController) {
        Swift.debugPrint("UISearchControllerDelegate invoked method: \(#function).")
    }
    
    func didPresentSearchController(_ searchController: UISearchController) {
        Swift.debugPrint("UISearchControllerDelegate invoked method: \(#function).")
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
        Swift.debugPrint("UISearchControllerDelegate invoked method: \(#function).")
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        Swift.debugPrint("UISearchControllerDelegate invoked method: \(#function).")
    }
    
}

