//
//  PPMarkdownViewController.swift
//  TeamDisk
//
//  Created by panwei on 2019/6/8.
//  Copyright © 2019 Wei & Meng. All rights reserved.
//
import UIKit
import Foundation
import Alamofire
import FilesProvider
import Down

typealias PPPTextView = UITextView


//UITextViewDelegate
class PPMarkdownViewController: PPBaseViewController,UITextViewDelegate {
//    let markdownParser = MarkdownParser()
    var markdownStr = "I support a *lot* of custom Markdown **Elements**, even `code`!"
    var historyList = [String]()
    var textView = PPPTextView()
    open var filePathStr: String = ""//文件相对路径
//    var webdav: WebDAVFileProvider?
    var closeAfterSave : Bool = false
    
    override func viewDidLoad() {
        pp_initView()
        self.title = self.filePathStr.split(string: "/").last
        PPFileManager.sharedManager.downloadFileViaWebDAV(path: self.filePathStr) { (contents, error) in
            guard let contents = contents else {
                return
            }
            debugPrint(String(data: contents, encoding: .utf8)!) // "hello world!"
            self.markdownStr = String.init(data: contents as Data, encoding: String.Encoding.utf8)!
            self.textView.text = self.markdownStr
            //NSAttributedString+Markdown 渲染
//            self.textView.attributedText = NSAttributedString(markdownRepresentation: self.markdownStr, attributes: [.font : UIFont.systemFont(ofSize: 17.0), .foregroundColor: UIColor.darkText ])
            
            //MARK:Down渲染
//            let down = Down(markdownString: self.markdownStr)
//            //DownAttributedStringRenderable 31行
//            let attributedString = try? down.toAttributedString(DownOptions.default, stylesheet: "* {font-family: Helvetica } code, pre { font-family: Menlo } code {position: relative;background-color: #f6f8fa;border-radius: 6px;} img {max-width: 100%;display: block;margin-left: auto;margin-right: auto;}")
//            self.textView.attributedText = attributedString
            
        }

        
        
        self.view.backgroundColor = UIColor.white

    }
    func pp_initView() {
        self.view.addSubview(textView)
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
//        textView.frame = self.view.bounds
        self.pp_viewEdgeEqualToSafeArea(textView)
        textView.backgroundColor = UIColor.white
        textView.font = UIFont.systemFont(ofSize: 16.0)
//        textView.attributedText = markdownParser.parse(markdown)
//        textView!.text = markdown
        
        textView.delegate = self
        
        let inputAccessoryView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: self.view.frame.width, height: 25))

        let keyboardDown = UIButton.init(frame: CGRect.init(x: self.view.frame.width-25, y: 0, width: 25, height: 25))
        keyboardDown.setImage(UIImage.init(named: "btn_down"), for: UIControl.State.normal)
        keyboardDown.addTarget(self, action: #selector(doneButtonAction(sender:)), for: UIControl.Event.touchUpInside)
        keyboardDown.backgroundColor = UIColor.white
        inputAccessoryView.addSubview(keyboardDown)
        
        
        textView.inputAccessoryView = inputAccessoryView
        
        let topToolView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: 120, height: 40))
        
        topToolView.addSubview(button0)
        topToolView.addSubview(button1)
        topToolView.addSubview(button2)
        
        let rightBarItem = UIBarButtonItem.init(customView: topToolView)
        
        self.navigationItem.rightBarButtonItem = rightBarItem
        
        self.setLeftBarButton()
    }
    override func pp_backAction() {
        if (PPUserInfo.pp_valueForSettingDict(key: "saveMarkdownWhenClose")) {
            self.closeAfterSave = true
            self.button2Action(sender: nil)
        } else {
            PPAlertAction.showAlert(withTitle: "是否保存已修改的文字", msg: "", buttonsStatement: ["不保存","要保存"]) { (index) in
                debugPrint("\(index)")
                if (index == 0) {
                    self.navigationController?.popViewController(animated: true)
                }
                else {
                    self.closeAfterSave = true
                    self.button2Action(sender: nil)
                }
            }
            
        }
    }
    
    func textViewDidChange(_ textView: PPPTextView) {
//        debugPrint(textView.text)
    }
    func textViewShouldBeginEditing(_ textView: PPPTextView) -> Bool {
        debugPrint("====Start")
        return true
    }
    func textView(_ textView: PPPTextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let newRange = Range(range, in: textView.text)!
        let mySubstring = textView.text![newRange]
        let myString = String(mySubstring)
        debugPrint("===shouldChangeTextIn \(myString)")
        return true
    }
    func textViewDidEndEditing(_ textView: PPPTextView) {
        debugPrint("===textViewDidEndEditing \(textView.attributedText.markdownRepresentation)")
        historyList.append(self.textView.text)
        debugPrint("historyList= \(historyList.count)")
    }
    @objc func button1Action(sender:UIButton)  {
        self.textView.resignFirstResponder()
        let webVC = PPWebViewController.init()
        var path = ""
        if self.filePathStr.hasSuffix("html") {
            path = PPDiskCache.shared.path + self.filePathStr
            webVC.fileURLStr = path
        }
        else {
            path = Bundle.main.url(forResource: "markdown", withExtension:"html")?.absoluteString ?? ""
            webVC.markdownStr = self.textView.text
            webVC.urlString = path // file:///....
        }
        
//        let fileURL = URL.init(fileURLWithPath: <#T##String#>)
        self.navigationController?.pushViewController(webVC, animated: true)
        
    }
    
    @objc func button2Action(sender:UIButton?)  {
        let item1 = PPUserInfo.shared
        debugPrint(item1.webDAVServerURL!)
        let stringToUpload:String = self.textView.text ?? ""
        if stringToUpload.length < 1 {
            PPHUD.showHUDText(message: "不支持保存空文件", view: self.view)
            return
        }
        debugPrint("===\(stringToUpload)")
        //MARK:保存
        self.textView.resignFirstResponder()
        PPFileManager.sharedManager.uploadFileViaWebDAV(path: self.filePathStr, contents: stringToUpload.data(using: .utf8), completionHander: { (error) in
            PPHUD.showHUDText(message: "保存成功", view: self.view)
            if (self.closeAfterSave) {
                self.navigationController?.popViewController(animated: true)
            }
        })

        

    }
    @objc func doneButtonAction(sender:UIButton)  {
        //保存
        self.textView.resignFirstResponder()
    }
    
    lazy var button0 : UIButton = {
        let button0 = UIButton.init(type: UIButton.ButtonType.custom)
        button0.frame = CGRect.init(x: 0, y: 0, width: 40, height: 40)
        button0.setImage(UIImage.init(named: "preview"), for: UIControl.State.normal)
        button0.addTarget(self, action: #selector(button1Action(sender:)), for: UIControl.Event.touchUpInside)
        return button0
    }()
    
    lazy var button1 : UIButton = {
        let button1 = UIButton.init(type: UIButton.ButtonType.custom)
        button1.frame = CGRect.init(x: 40, y: 0, width: 40, height: 40)
        button1.setImage(UIImage.init(named: "share"), for: UIControl.State.normal)
        button1.addTarget(self, action: #selector(button1Action(sender:)), for: UIControl.Event.touchUpInside)
        return button1
    }()
    lazy var button2 : UIButton = {
        let button2 = UIButton.init(type: UIButton.ButtonType.custom)
        button2.frame = CGRect.init(x: 80, y: 0, width: 40, height: 40)
        button2.setImage(UIImage.init(named: "done"), for: UIControl.State.normal)
        button2.addTarget(self, action: #selector(button2Action(sender:)), for: UIControl.Event.touchUpInside)
        return button2
    }()
    
    
}
