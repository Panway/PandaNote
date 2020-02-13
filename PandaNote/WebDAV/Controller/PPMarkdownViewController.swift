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
    var markdown = "I support a *lot* of custom Markdown **Elements**, even `code`!"
    var historyList = [String]()
    var textView : PPPTextView?
    open var filePathStr: String = ""//相对路径
    var webdav: WebDAVFileProvider?
    var closeAfterSave : Bool = false
    override func viewDidLoad() {
        pp_initView()
        let server: URL = URL(string: PPUserInfo.shared.webDAVServerURL ?? "")!

        let credential = URLCredential(user: PPUserInfo.shared.webDAVUserName ?? "",
                                       password: PPUserInfo.shared.webDAVPassword ?? "",
                                       persistence: .permanent)
        
        webdav = WebDAVFileProvider(baseURL: server, credential: credential)!
        webdav?.contents(path: self.filePathStr, completionHandler: {
            contents, error in
            if let contents = contents {
                print(String(data: contents, encoding: .utf8)!) // "hello world!"
                self.markdown = String.init(data: contents as Data, encoding: String.Encoding.utf8)!
//                let down = Down(markdownString: self.markdown)
//                let attributedString = try? down.toAttributedString()

                DispatchQueue.main.async {
                    self.textView?.text = self.markdown
                    //MARK:渲染
//                    self.textView?.attributedText = attributedString
                }
            }
        })

        
        
        self.view.backgroundColor = UIColor.white

    }
    func pp_initView() {
        textView = PPPTextView(frame: self.view.bounds);
        self.view.addSubview(textView!)
        textView!.backgroundColor = UIColor.white
        textView?.font = UIFont.systemFont(ofSize: 16.0)
//        textView.attributedText = markdownParser.parse(markdown)
//        textView!.text = markdown
        
        textView?.delegate = self
        
        let inputAccessoryView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: self.view.frame.width, height: 25))

        let keyboardDown = UIButton.init(frame: CGRect.init(x: self.view.frame.width-25, y: 0, width: 25, height: 25))
        keyboardDown.setImage(UIImage.init(named: "btn_down"), for: UIControl.State.normal)
        keyboardDown.addTarget(self, action: #selector(doneButtonAction(sender:)), for: UIControl.Event.touchUpInside)
        keyboardDown.backgroundColor = UIColor.white
        inputAccessoryView.addSubview(keyboardDown)
        
        
        textView?.inputAccessoryView = inputAccessoryView
        
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
//        print(textView.text)
    }
    func textViewShouldBeginEditing(_ textView: PPPTextView) -> Bool {
        print("====Start")
        return true
    }
    func textView(_ textView: PPPTextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let newRange = Range(range, in: textView.text)!
        let mySubstring = textView.text![newRange]
        let myString = String(mySubstring)
        print("Change= \(myString)")
        return true
    }
    func textViewDidEndEditing(_ textView: PPPTextView) {
        print("textViewDidEndEditing= \(textView.text ?? "")")
        historyList.append(textView.text)
        print("historyList= \(historyList.count)")
    }
    @objc func button1Action(sender:UIButton)  {
        textView?.resignFirstResponder()
        let webVC = XDWebViewController.init()
        let path = Bundle.main.url(forResource: "markdown", withExtension:"html")
        
//        let fileURL = URL.init(fileURLWithPath: <#T##String#>)
        webVC.urlString = path!.absoluteString
        webVC.markdownStr = textView!.text
        self.navigationController?.pushViewController(webVC, animated: true)
        
    }
    struct PandaStringArrayEncoding: ParameterEncoding {
        private let array: [String]
        
        init(array: [String]) {
            self.array = array
        }
        
        func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
            var urlRequest = try urlRequest.asURLRequest()
//
//            let data = try JSONSerialization.data(withJSONObject: array, options: [])
//
//            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
//                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
//            }
//
//            urlRequest.httpBody = data
            let markdown = parameters?["rawString"] as! String//直接取原始String，不要foo=bar这种字符串、不URL编码
            
            urlRequest.httpBody = markdown.data(using: .utf8, allowLossyConversion: false)

            return urlRequest
        }
    }
    @objc func button2Action(sender:UIButton?)  {
        let item1 = PPUserInfo.shared
        print(item1.webDAVServerURL!)
        let stringToUpload:String = textView?.text ?? ""
        if stringToUpload.length < 1 {
            PPHUD.showHUDText(message: "不支持保存空文件", view: self.view)
            return
        }
        //MARK:保存
        textView?.resignFirstResponder()
//        Alamofire.request(self.item.href, method: .put, parameters: parameters, encoding: URLEncoding(destination: .httpBody))
        webdav?.writeContents(path: self.filePathStr, contents: stringToUpload.data(using: .utf8), completionHandler: { (error) in
//            print("Data: \(error)")
            if error == nil {
                DispatchQueue.main.async {
                    PPHUD.showHUDText(message: "保存成功", view: self.view)
                    if (self.closeAfterSave) {
                        self.navigationController?.popViewController(animated: true)
                    }
                }
            }
        })
/*
        let parameters: Parameters = ["rawString": stringToUpload]
        let filePath : String = (PPUserInfo.shared.webDAVServerURL ?? "") + self.filePathStr

        Alamofire.request(filePath, method: .put, parameters: parameters, encoding: PandaStringArrayEncoding(array: [textView!.text]))
            .authenticate(user: PPUserInfo.shared.webDAVUserName ?? "", password: PPUserInfo.shared.webDAVPassword ?? "")
            .responseData { response in
            debugPrint("All Response Info: \(response)")
            
            if let data = response.result.value, let utf8Text = String(data: data, encoding: .utf8) {
                print("Data: \(utf8Text)")
            }
                if (response.value != nil) {
                    print("Success")
                    PPHUD.showHUDText(message: "保存成功", view: self.view)
                }
        }
*/
    }
    @objc func doneButtonAction(sender:UIButton)  {
        //保存
        textView?.resignFirstResponder()
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
