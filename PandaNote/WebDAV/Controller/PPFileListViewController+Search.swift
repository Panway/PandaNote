//
//  PPFileListViewController+Search.swift
//  PandaNote
//
//  Created by Panway on 2020/11/20.
//  Copyright © 2020 Panway. All rights reserved.
//

import Foundation
import PopMenu

@objc enum PPFileListOrder : Int {
    case timeDesc //时间降序
    case timeAsc //时间升序
    case nameAsc //名字升序
    case nameDesc //名字降序
    case sizeDesc //大小降序
    case sizeAsc //大小升序
    case clickCountDesc //最常访问
    case type //文件夹在前面（不排序的结果）
}
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
        searchController.searchBar.tintColor = PPCOLOR_GREEN
//        searchController.searchBar.scopeButtonTitles = ["A","B","C","D"]

        
        if #available(iOS 11.0, *) {
            // 将搜索栏放置在导航栏中 Place the search bar in the navigation bar.
//            navigationItem.searchController = searchController
            // 滚动时隐藏搜索栏
//            navigationItem.hidesSearchBarWhenScrolling = false
        } else {
            // Fallback on earlier versions
        }
//        self.tableView.tableHeaderView = searchController.searchBar;

        definesPresentationContext = true
    }
}
// MARK: - 搜索功能
// MARK: UISearchBarDelegate

extension PPFileListViewController: UISearchBarDelegate {
    // 键盘的搜索按钮点击后
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        PPFileManager.shared.searchFile(path: self.pathStr, searchText: searchBar.text) { (files, isF, error) in
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

// MARK:  UISearchControllerDelegate

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

//MARK: - 移动文件（夹）到其他文件夹功能
extension PPFileListViewController {
    func setupMoveUI() {
        self.title = "移动到"
        leftButton = UIButton(type: .custom)
        leftButton.frame = CGRect(x: 0, y: 0, width: 66, height: 44)
        leftButton.setTitle("取消", for: .normal)
        leftButton.setTitleColor(PPCOLOR_GREEN, for: .normal)
        
        rightButton = UIButton(type: .custom)
        rightButton.frame = CGRect(x: 0, y: 0, width: 66, height: 44)
        rightButton.setTitle("完成", for: .normal)
        rightButton.setTitleColor(PPCOLOR_GREEN, for: .normal)

        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: leftButton)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightButton)
        leftButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        rightButton.addTarget(self, action: #selector(submitMove), for: .touchUpInside)
    }
    
    @objc func dismissSelf() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func submitMove() {
        PPAlertAction.showAlert(withTitle: "移动到这里？", msg: "", buttonsStatement: ["确定","取消"]) { (index) in
            if index == 0 {
                let first = self.navigationController?.viewControllers.first as! PPFileListViewController
                guard let fileName = first.filePathToBeMove.split(separator: "/").last else {
                    PPHUD.showHUDFromTop("移动失败，文件名有问题")
                    return
                }
                //如果是本地文件就上传（上传App配置）
                if (first.filePathToBeMove.contains(PPUserInfo.shared.pp_mainDirectory)) {
                    let path = URL(fileURLWithPath: PPUserInfo.shared.pp_mainDirectory+"/PP_JSONConfig.json")
                    let jsonData = try? Data(contentsOf: path)
                    PPFileManager.shared.createFile(path: self.pathStr + fileName, contents: jsonData) { (error) in
                        if error != nil {
                            PPHUD.showHUDFromTop("上传配置失败", isError: true)
                        }
                        else {
                            PPHUD.showHUDFromTop("上传配置成功")
                            self.dismissSelf()
                        }
                    }
                    return
                }
                PPFileManager.shared.moveRemoteFile(pathOld: first.filePathToBeMove,
                                                       pathNew: self.pathStr + fileName) { (error) in
                    debugPrint(error?.localizedDescription)
                    if error == nil {
                        PPHUD.showHUDFromTop("移动成功，请刷新当前页面")
                        self.dismissSelf()
                    }
                }
                
            }
        }
    }
    //排序
    func sort(array:[PPFileObject], orderBy:PPFileListOrder) -> Array<PPFileObject> {
        var res = [PPFileObject]()
        switch orderBy {
        case .timeDesc:
            res = array.sorted { a, b in
                a.modifiedDate > b.modifiedDate
            }
        case .timeAsc:
            res = array.sorted { a, b in
                a.modifiedDate < b.modifiedDate
            }
        case .nameAsc:
            res = array.sorted { a, b in
                a.name < b.name
            }
        case .nameDesc:
            res = array.sorted { a, b in
                a.name > b.name
            }
        case .sizeAsc:
            res = array.sorted { a, b in
                a.size < b.size
            }
        case .sizeDesc:
            res = array.sorted { a, b in
                a.size > b.size
            }
        case .clickCountDesc:
            res = array.sorted { a, b in
                a.clickCount > b.clickCount
            }
        case .type:
            res = array
        }
        return res;
    }
    func sortRecentFileList() {
        if PPAppConfig.shared.showMarkdownOnly {
            self.dataSource = self.rawDataSource.filter({ fileObj in
                fileObj.name.hasSuffix(".md") || fileObj.name.hasSuffix(".markdown")
            })
        }
        else {
            self.dataSource = self.rawDataSource
        }
        
        
    }
    @objc func recentMore(sender:UIButton) {
        debugPrint("recent more btn 最近")
        let status = PPAppConfig.shared.showMarkdownOnly ? " ✅" : ""
        self.dropdown.dataSource = ["仅显示Markdown" + status]
        self.dropdown.selectionAction = { (index: Int, item: String) in
            if(index == 0) {
                PPAppConfig.shared.showMarkdownOnly = !PPAppConfig.shared.showMarkdownOnly
                PPAppConfig.shared.setItem("showMarkdownOnly","\(PPAppConfig.shared.showMarkdownOnly ? 1 : 0)")
                self.sortRecentFileList()
                self.collectionView.reloadData()
            }
        }
        self.dropdown.anchorView = sender
        self.dropdown.show()
    }
    
    func getOrderSuffix(_ orderType:PPFileListOrder) {
        var order = ""
        switch orderType {
        case .timeAsc, .nameAsc, .sizeAsc:
            order = "↑"
        case .timeDesc, .nameDesc, .sizeDesc:
            order = "↓"
        default:
            order = ""
        }
    }
    func showSortPopMenu(anchorView:UIView) {
        let map = ["0":"时间↓","1":"时间↑","3":"名称↓","2":"名称↑","4":"大小↓","5":"大小↑"
                   ,"6":"最常访问✅"]
        var dataS = ["时间","名称","大小"]
        if isRecentFiles {
            dataS.append("最常访问")
        }
        let currentOrder = "\(PPAppConfig.shared.fileListOrder.rawValue)"
        guard let selectStr = map[currentOrder] else {return}
        self.dropdown.dataSource = dataS.map({selectStr.hasPrefix($0) ? selectStr : $0});
        self.dropdown.selectionAction = { (index: Int, item: String) in
            var newOrder = PPFileListOrder.timeDesc
            if (item.contains("时间↓")) {
                newOrder = .timeAsc
            }
            else if (item.contains("时间") || item.contains("时间↑")) {
                newOrder = .timeDesc
            }
            else if (item.contains("名称↑")) {
                newOrder = .nameDesc
            }
            else if (item.contains("名称") || item.contains("名称↓")) {
                newOrder = .nameAsc
            }
            else if (item.contains("大小↓")) {
                newOrder = .sizeAsc
            }
            else if (item.contains("大小") || item.contains("大小↑")) {
                newOrder = .sizeDesc //未选择大小、或已选择大小升序
            }
            else if (item.contains("最常访问")) {
                newOrder = .clickCountDesc
            }
            PPAppConfig.shared.setItem("fileListOrder","\(newOrder.rawValue)")
            PPAppConfig.shared.fileListOrder = newOrder
            self.dataSource = self.sort(array: self.dataSource, orderBy: newOrder)
            self.collectionView.reloadData()
        }
        self.dropdown.anchorView = anchorView
        self.dropdown.show()
    }
    //MARK:最近文件
    /// 移除后返回删除前点击次数
    @discardableResult
    func removeFromRecentFiles(_ fileObj:PPFileObject) -> Int64 {
        let list = PPUserInfo.shared.recentFiles
        for i in 0..<list.count {
            if fileObj == list[i] {
                let clickCount = list[i].clickCount
                PPUserInfo.shared.recentFiles.remove(at: i)
                return clickCount
            }
        }
        return 0
    }
    /// 插入最近浏览的文件或目录到最近浏览列表（如果有需要的话）
    func insertToRecentFiles(_ fileObj:PPFileObject, _ isRecent:Bool) {
        let oldCount = removeFromRecentFiles(fileObj)
        fileObj.clickCount = oldCount + 1
        
        if let currentIndex = PPUserInfo.shared.serverNameIndexMap[PPUserInfo.shared.webDAVRemark],
        isRecent == false {
            fileObj.associatedServerName = PPUserInfo.shared.webDAVRemark
            fileObj.associatedServerID = currentIndex
        }

        PPUserInfo.shared.recentFiles.insert(fileObj, at: 0)
        if PPUserInfo.shared.recentFiles.count > 50 {
            PPUserInfo.shared.recentFiles.removeLast()
        }
    }
}

//MARK: - 增加各种云服务功能
extension PPFileListViewController {
    ///添加云服务
    @objc func addCloudService() {
        let vc = PPAddCloudServiceViewController()
        self.navigationController?.pushViewController(vc, animated: true)
    }
    /// 编辑云服务
    func editCloudService() {
        let vc = PPEditCloudServiceVC()
        self.navigationController?.pushViewController(vc, animated: true)
    }
    ///设置导航栏标题
    func setNavTitle(_ title:String?=nil,_ showArrow:Bool?=false) {
        let title = (title != nil) ? title : String(self.pathStr.split(separator: "/").last ?? "" + PPUserInfo.shared.webDAVRemark)
        if isRecentFiles && showArrow == false {
            self.setTitle("最近", action: #selector(recentMore(sender:)))
            return
        }
        else if (self.navigationController?.viewControllers.count ?? 0) > 1 && showArrow == false {
            self.navigationItem.title = title
            return
        }
        if PPUserInfo.shared.pp_serverInfoList.count < 1 {
            return//没有服务器信息就不显示下箭头
        }
        self.setTitle(title, action: #selector(showAddCloudServiceView))
        
        
    }
    @objc func showAddCloudServiceView(for barButtonItem: UIBarButtonItem) {
        // Create menu controller with actions

        var menuList = [PopMenuDefaultAction]()
        for item in PPUserInfo.shared.pp_serverInfoList {
            debugPrint(item)
            let item = PopMenuDefaultAction(title: item["PPWebDAVRemark"], image: nil, color: .darkText)
            menuList.append(item)
        }
        
        let controller = PopMenuViewController(sourceView: barButtonItem, actions: menuList)
        
        // Customize appearance
        controller.appearance.popMenuFont = UIFont(name: "AvenirNext-DemiBold", size: 16)!
        controller.appearance.popMenuColor = PopMenuColor.configure(background: PopMenuActionBackgroundColor.solid(fill: PPCOLOR_GREEN), action: PopMenuActionColor.tint(UIColor.red))

//        controller.appearance.popMenuBackgroundStyle = .blurred(.dark)
        // Configure options
        controller.shouldDismissOnSelection = true//选择后是否自动消失
        controller.delegate = self
        controller.appearance.popMenuColor.backgroundColor = .solid(fill: .white)

        controller.didDismiss = { selected in
            print("Menu dismissed: \(selected ? "selected item" : "no selection")")
        }
        
        // Present menu controller
        present(controller, animated: true, completion: nil)
    }
    func popMenuDidSelectItem(_ popMenuViewController: PopMenuViewController, at index: Int) {
        debugPrint(index)
        // 记住上次选中第几个
        PPUserInfo.shared.pp_Setting["pp_lastSeverInfoIndex"] = index
        PPUserInfo.shared.pp_lastSeverInfoIndex = index
        let info = PPUserInfo.shared.pp_serverInfoList[index]
        setNavTitle(info["PPWebDAVRemark"])
        PPUserInfo.shared.updateCurrentServerInfo(index: index)
        PPFileManager.shared.initCloudServiceSetting()
        getFileListData()
    }
}

//MARK: - Style 样式
extension PPFileListViewController {
    func setTitle(_ title:String?, action: Selector) {
        titleViewButton = UIButton(type: .custom)
        titleViewButton.frame = CGRect(x: 0, y: 0, width: 66, height: 44)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor.darkGray,
        ]
        
        let image = UIImage(cgImage: (UIImage(named: "arrow_right")?.cgImage!)!, scale: UIScreen.main.scale, orientation: .right)
        //#imageLiteral(resourceName: "arrow_right")
        titleViewButton.setAttributedTitle(NSMutableAttributedString.pp_AttributedText(withTitle: title, titleAttributes: attributes, image: image, space: 28), for: .normal)
        self.navigationItem.titleView = titleViewButton
        titleViewButton.addTarget(self, action: action, for: .touchUpInside)

    }
}
