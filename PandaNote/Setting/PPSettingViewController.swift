//
//  PPSettingViewController.swift
//  PandaNote
//
//  Created by panwei on 2019/8/29.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import UIKit
import DropDown

class PPSettingViewController: PPBaseViewController,UITableViewDataSource,UITableViewDelegate,PPSettingCellDelegate {
    
    
    var dataSource : [[[String:String]]] = []
    var headerList : [String] = []
    var tableView = UITableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.barStyle = .black
        tableView = UITableView(frame: self.view.bounds,style: .grouped)
        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(self.pp_safeLayoutGuideTop())
            make.left.right.bottom.equalToSuperview()
        }
        tableView.dataSource = self
        tableView.delegate = self
        self.tableView.register(PPSettingCell.self, forCellReuseIdentifier: kPPBaseCellIdentifier)
        tableView.tableFooterView = UIView()
        tableView.register(PPTableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: kPPTableViewHeaderFooterView)
        tableView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        guard let path = Bundle.main.url(forResource: "app_setting_option.json", withExtension: nil), let jsonData = try? Data(contentsOf: path) else {return}
        if let json = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) {
            dataSource = json as! [[[String:String]]]
            for item in dataSource {
                for subitem in item {
                    if let categoryStr = subitem["category"] {
                        headerList.append(categoryStr)
                    }
                }
            }
        }
        
    }
    
    @objc func injected() {
//        dataSource = ["WebDAV Setting","Web"]
        self.tableView.reloadData()
    }
    
    
    func didClickSwitch(sender: UISwitch, name: String, saveKey:String,section:Int,row:Int) {
        let item = self.dataSource[section][row]
        debugPrint("[设置项]\(item["name"] ?? ""):\(sender.isOn)")
        if item["name"] != nil {
            PPUserInfo.shared.pp_Setting.updateValue(sender.isOn ? "1" : "0", forKey: item["key"] ?? "none")
        }
    }
    //MARK:- tab;le
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 24
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let customFooterView = tableView.dequeueReusableHeaderFooterView(withIdentifier: kPPTableViewHeaderFooterView)
        customFooterView?.textLabel?.text = headerList[section]
//        customFooterView?.detailTextLabel?.text = "detailTextLabel"
        return customFooterView
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kPPBaseCellIdentifier, for: indexPath) as! PPSettingCell
        let item = self.dataSource[indexPath.section][indexPath.row]
        cell.titleLB.text = item["name"]
        if let detail = item["detail"] {
            cell.detailLB.text = detail
        }
        if let showSwitch = item["showSwitch"],showSwitch.bool == true {
            cell.switchBtn.isOn = PPUserInfo.pp_boolValue(item["key"] ?? "")
        }
        cell.pp_section = indexPath.section
        cell.pp_row = indexPath.row
        cell.delegate = self
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let obj = self.dataSource[indexPath.section][indexPath.row]["name"]
        if obj == "FLEX Debug Enable" {
            #if DEBUG
            FLEXManager.shared.showExplorer()
            #endif
        }
        else if obj == "保存设置到" {
            let vc = PPFileListViewController()
            vc.filePathToBeMove = PPUserInfo.shared.pp_mainDirectory + "/PP_JSONConfig.json"
            vc.isMovingMode = true
            let nav = UINavigationController(rootViewController: vc)
            self.present(nav, animated: true, completion: nil)
        }
        else if obj == "底部Tab默认选中第几个" {
            let dropDown = DropDown()

            //下拉菜单将在其上显示的视图 The view to which the drop down will appear on
            dropDown.anchorView = tableView.cellForRow(at: indexPath) // UIView or UIBarButtonItem
            dropDown.direction = .bottom
            dropDown.bottomOffset = CGPoint(x: 200, y: 0)
            // 要显示的项目列表。可以动态更改 The list of items to display. Can be changed dynamically
            dropDown.dataSource = ["1", "2", "3", "4"]
            
            // 选择时触发动作 Action triggered on selection
            dropDown.selectionAction = { (index: Int, item: String) in
                print("Selected item: \(item) at index: \(index)")
                PPUserInfo.shared.pp_Setting.updateValue(index, forKey:"pp_tab_selected_index")
            }

            // 将设置自定义宽度，而不是锚视图宽度 Will set a custom width instead of the anchor view width
            dropDown.width = 55
            DropDown.appearance().setupCornerRadius(10)
            dropDown.show()
        }
        else if obj == "markdown文本解析器设置" {
            let dropDown = DropDown()
            dropDown.anchorView = tableView.cellForRow(at: indexPath) // UIView or UIBarButtonItem
            dropDown.direction = .bottom
            dropDown.bottomOffset = CGPoint(x: 100, y: 0)
            dropDown.dataSource = ["none", "NSAttributedString+Markdown", "Down"]
            dropDown.selectionAction = { (index: Int, item: String) in
                PPUserInfo.shared.pp_Setting.updateValue(dropDown.dataSource[index], forKey:"pp_markdownParseMethod")
            }
            DropDown.appearance().setupCornerRadius(10)
            dropDown.show()
        }
        else if obj == "编辑器主题样式" {
            let dropDown = DropDown()
            dropDown.anchorView = tableView.cellForRow(at: indexPath) // UIView or UIBarButtonItem
            dropDown.direction = .bottom
            dropDown.bottomOffset = CGPoint(x: 200, y: 0)
            dropDown.width = 100;
            dropDown.dataSource = ["默认", "锤子便签", "深黑", "浅黑","Vue"]
            dropDown.selectionAction = { (index: Int, item: String) in
                PPUserInfo.shared.pp_Setting.updateValue(dropDown.dataSource[index], forKey:"pp_markdownEditorStyle")
            }
            DropDown.appearance().setupCornerRadius(10)
            dropDown.show()
        }
        else if obj == "图片压缩质量" {
            let dropDown = DropDown()
            dropDown.anchorView = tableView.cellForRow(at: indexPath)
            dropDown.direction = .bottom
            dropDown.bottomOffset = CGPoint(x: 200, y: 0)
            dropDown.dataSource = ["0.1", "0.2", "0.3", "0.4","0.5"]
            dropDown.selectionAction = { (index: Int, item: String) in
                PPUserInfo.shared.pp_Setting.updateValue(dropDown.dataSource[index], forKey:"pp_imageCompressionQuality")
            }
            dropDown.width = 55
            DropDown.appearance().setupCornerRadius(10)
            dropDown.show()
        }
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let item = self.dataSource[indexPath.section][indexPath.row]
        if let detail = item["detail"],detail.length > 0 {
            return 65.0
        }
        return 44.0
    }
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
