//
//  PPPriceTagViewController.swift
//  PandaNote
//
//  Created by panwei on 2020/1/26.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import UIKit

@available(macCatalyst 14.0, *)
class PPPriceTagViewController: PPBaseViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let scanToSearchBtn = UIButton.init(type: UIButton.ButtonType.custom)
        scanToSearchBtn.setTitle("扫码查询", for: UIControl.State.normal)
        scanToSearchBtn.backgroundColor = UIColor(red:0.27, green:0.68, blue:0.49, alpha:1.00)
        self.view.addSubview(scanToSearchBtn)
        scanToSearchBtn.addTarget(self, action: #selector(scanToSearch), for: UIControl.Event.touchUpInside)
        scanToSearchBtn.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize.init(width: 200, height: 100))
            make.top.equalToSuperview().offset(100)
            make.centerX.equalToSuperview()
        }
        
        let scanToRecordBtn = UIButton.init(type: UIButton.ButtonType.custom)
        scanToRecordBtn.setTitle("扫码录入/更新", for: UIControl.State.normal)
        scanToRecordBtn.backgroundColor = UIColor(red:0.27, green:0.68, blue:0.49, alpha:1.00)
        self.view.addSubview(scanToRecordBtn)
        scanToRecordBtn.addTarget(self, action: #selector(scanToRecord), for: UIControl.Event.touchUpInside)
        scanToRecordBtn.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize.init(width: 200, height: 100))
            make.top.equalTo(scanToSearchBtn.snp.bottom).offset(44)
            make.centerX.equalToSuperview()
        }
        
    }
    
    @available(macCatalyst 14.0, *)
    @objc func scanToRecord() {
        let vc = PPScanViewController()
        vc.scanCompletionHandler = {(codeString) in
            debugPrint(codeString)
            let vc = PPPriceRecordViewController.init()
            vc.codeString = codeString
            self.navigationController?.pushViewController(vc, animated: true)
        }
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func scanToSearch() {
        let vc = PPPriceRecordViewController.init()
        self.navigationController?.pushViewController(vc, animated: true)
    }
}



//MARK:价格录入界面
class PPPriceRecordViewController: PPBaseViewController {
    var codeString = ""
    let codeLB : UILabel! = UILabel()
    var priceTF : UITextField!
    var wholesalePriceTF : UITextField!
    var nameTF : UITextField!
    var remarkTF : UITextField!
    var categoryTF : UITextField!
    var submitBtn : UIButton!
    var goodID = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.groupTableViewBackground
        addSubViews()
        let dbModel = PPPriceDBModel()
        let sqliteManager = PPSQLiteManager(delegate: dbModel)
        sqliteManager.loadDB()
        let searchCode = sqliteManager.loadMatch(table: "pp_price", match: "code like " + self.codeString, value: [])
        if (searchCode.count > 0) {
            let result = searchCode[0]
            priceTF.text = result["price"] as? String
            wholesalePriceTF.text = result["whole_price"] as? String
            nameTF.text = result["name"] as? String
            remarkTF.text = result["remark"] as? String
            categoryTF.text = result["category"] as? String
            debugPrint(searchCode)
            goodID = result["id"] as! Int
        }
    }
    
    func addSubViews() {
        priceTF = UITextField()
        self.view.addSubview(priceTF)
        priceTF.backgroundColor = UIColor.white
        priceTF.placeholder = "物品单价"
        priceTF.font = UIFont.systemFont(ofSize: 18)
        priceTF.keyboardType = UIKeyboardType.numbersAndPunctuation
        priceTF.returnKeyType = UIReturnKeyType.done
        priceTF.clearButtonMode = UITextField.ViewMode.whileEditing
        priceTF.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        priceTF.snp.makeConstraints { (make) in
            make.left.equalTo(self.view).offset(15)
            make.width.equalTo(150)
            make.height.equalTo(33)
            make.top.equalTo(self.view).offset(100)
        }
        //        priceTF = aTF
        priceTF.becomeFirstResponder()
        
        
        wholesalePriceTF = UITextField()
        self.view.addSubview(wholesalePriceTF)
        wholesalePriceTF.backgroundColor = UIColor.white
        wholesalePriceTF.placeholder = "整卖价格"
        wholesalePriceTF.font = UIFont.systemFont(ofSize: 18)
        wholesalePriceTF.keyboardType = UIKeyboardType.numbersAndPunctuation
        wholesalePriceTF.returnKeyType = UIReturnKeyType.done
        wholesalePriceTF.clearButtonMode = UITextField.ViewMode.whileEditing
        wholesalePriceTF.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        wholesalePriceTF.snp.makeConstraints { (make) in
//            make.left.equalTo(self.view).offset(15)
            make.right.equalTo(self.view).offset(-15)
            make.height.equalTo(33)
            make.width.equalTo(150)
            make.top.equalTo(self.view).offset(100)
        }
        
        
        nameTF = UITextField()
        self.view.addSubview(nameTF)
        nameTF.backgroundColor = UIColor.white
        nameTF.placeholder = "物品名字"
        nameTF.font = UIFont.systemFont(ofSize: 18)
        //        nameTF.keyboardType = UIKeyboardType.numberPad
        nameTF.returnKeyType = UIReturnKeyType.done
        nameTF.clearButtonMode = UITextField.ViewMode.whileEditing
        nameTF.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        nameTF.snp.makeConstraints { (make) in
            make.left.equalTo(self.view).offset(15)
            make.right.equalTo(self.view).offset(-15)
            make.height.equalTo(33)
            make.top.equalTo(self.priceTF.snp.bottom).offset(11)
        }
        
        
        remarkTF = UITextField()
        self.view.addSubview(remarkTF)
        remarkTF.backgroundColor = UIColor.white
        remarkTF.placeholder = "物品备注"
        remarkTF.font = UIFont.systemFont(ofSize: 18)
        //        nameTF.keyboardType = UIKeyboardType.numberPad
        remarkTF.returnKeyType = UIReturnKeyType.done
        remarkTF.clearButtonMode = UITextField.ViewMode.whileEditing
        remarkTF.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        remarkTF.snp.makeConstraints { (make) in
            make.left.equalTo(self.view).offset(15)
            make.right.equalTo(self.view).offset(-15)
            make.height.equalTo(33)
            make.top.equalTo(self.nameTF.snp.bottom).offset(11)
        }

        categoryTF = UITextField()
        self.view.addSubview(categoryTF)
        categoryTF.backgroundColor = UIColor.white
        categoryTF.placeholder = "类别(1烟2酒3吃4用)"
        categoryTF.font = UIFont.systemFont(ofSize: 18)
        categoryTF.keyboardType = UIKeyboardType.numberPad
        categoryTF.returnKeyType = UIReturnKeyType.done
        categoryTF.clearButtonMode = UITextField.ViewMode.whileEditing
        categoryTF.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        categoryTF.snp.makeConstraints { (make) in
            make.left.equalTo(self.view).offset(15)
            make.right.equalTo(self.view).offset(-15)
//            make.width.equalTo(88)
            make.height.equalTo(33)
            make.top.equalTo(self.remarkTF.snp.bottom).offset(11)
        }
        
        
//        codeLB = UILabel()
        codeLB.text = "条形码：" + self.codeString
//        codeLB = UILabel.init()
        self.view.addSubview(codeLB)
        codeLB.snp.makeConstraints { (make) in
            make.left.equalTo(self.view).offset(15)
            make.right.equalTo(self.view).offset(-15)
            make.height.equalTo(33)
            make.top.equalTo(self.categoryTF.snp.bottom).offset(11)
        }
        
        submitBtn = UIButton.init(type: UIButton.ButtonType.custom)
        self.view.addSubview(submitBtn)
        submitBtn.setTitle("提交", for: UIControl.State.normal)
        submitBtn.backgroundColor = UIColor.red
        submitBtn.addTarget(self, action: #selector(submit), for: UIControl.Event.touchUpInside)
        submitBtn.snp.makeConstraints { (make) in
            make.left.equalTo(self.view).offset(15)
            make.right.equalTo(self.view).offset(-15)
            make.height.equalTo(44)
            make.top.equalTo(self.codeLB.snp.bottom).offset(11)
        }
        
        
    }
    
    @objc func submit() {
        if priceTF.text!.length < 1 {
            PPHUD.showHUDText(message: "拜托，价格写下", view: self.view)
            return
        }
        
        let dbModel = PPPriceDBModel()
        let sqliteManager = PPSQLiteManager(delegate: dbModel)
        sqliteManager.loadDB()
        let searchCode = sqliteManager.loadMatch(table: "pp_price", match: "code like " + self.codeString, value: [])
        if searchCode.count > 0 {
            sqliteManager.update(table: "pp_price", data:
                ["price" : priceTF.text!,
                 "id":goodID, //不整这个不行
                 "code" : self.codeString,
                 "whole_price" : wholesalePriceTF.text!,
                 "name" : nameTF.text!,
                 "category" : categoryTF.text!,
                 "remark" : remarkTF.text!])
            PPHUD.showHUDText(message: "更新成功！", view: self.view)
        }
        else {
            sqliteManager.insert(table: "pp_price", data:
                ["price" : priceTF.text!,
                 "code" : self.codeString,
                 "whole_price" : wholesalePriceTF.text!,
                 "name" : nameTF.text!,
                 "category" : categoryTF.text!,
                 "remark" : remarkTF.text!])
            PPHUD.showHUDText(message: "录入成功！", view: self.view)
        }

//        let sql = "create table if not exists pp_price(id integer primary key autoincrement,code varchar(20) not null,price varchar(20) default 0,whole_price varchar(20) ,remark varchar(20) )"
//        
//        
//        sqliteManager.operation(process: sql, value: [])

        
    }
}

class PPPriceDBModel: NSObject {
    
}

//MARK: Model
extension PPPriceDBModel: SQLDelegate {
    var sqlSyntaxs: [String] {
        return []
    }
    
    var dbPathName: String {
        return "/priceTag.db"
    }
    
    func tablePrimaryKey(table: String) -> String {
        return "id"
    }
}
