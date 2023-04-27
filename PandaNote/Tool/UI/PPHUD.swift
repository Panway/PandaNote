//
//  PPHUD.swift
//  PandaNote
//
//  Created by panwei on 2019/8/29.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import UIKit
import MBProgressHUD

extension UILabel {
    func getSize(constrainedWidth: CGFloat) -> CGSize {
        return systemLayoutSizeFitting(CGSize(width: constrainedWidth, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
    }
}
//fileprivate var cancelHide = false
class PPHUD: NSObject {
    
    static let shared = PPHUD()
    
    var waitHUb:MBProgressHUD?
    let deleteBGView = UIView()
    let annularView = MBRoundProgressView()
    var canceled = false
    var hud = MBProgressHUD(view: UIApplication.shared.keyWindow!)

    lazy var revokeBtn : UIButton = {
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        button.setTitle("撤销", for: .normal)
        button.setTitleColor("#3eaf7c".pp_HEXColor(), for: .normal) // #4abf8a 浅色
//        button.setImage(UIImage(named: "revoke"), for: .normal)
//        button.addTarget(self, action: #selector(revoke), for: .touchUpInside)
        return button
    }()
    
    private var deleteLabel : UILabel = {
        let label = UILabel();
        label.text = "文件已删除"
        label.textColor = "FFFFFF".HEXColor()
        label.font = UIFont.boldSystemFont(ofSize: 15)
        label.frame = CGRect(x: 55, y: 5, width: 88, height: 35)
        return label
    }()
    //MARK: 顶部提示信息框
    class func showHUDFromTop(_ message:String, isError:Bool?=false) -> Void {
        if(message.length < 1) {
            return
        }
        guard let keyWindow = UIApplication.shared.keyWindow else { return }
        var tag = 9998
        let width = max(320, keyWindow.frame.width)
        var hudH = CGFloat(20.0)
        var hudLeft = 80.0
        if let lastView = keyWindow.viewWithTag(tag) as? UILabel {
            tag = 9999
            lastView.frame.origin.x = 20.0
            hudLeft = lastView.frame.origin.x + lastView.frame.size.width + 20
            
//            lastView.text = (lastView.text ?? "") + " " + message
//            cancelHide = true
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                lastView.removeFromSuperview()
//                cancelHide = false
//            }
        }
        if #available(iOS 11.0, *) {
            hudH = keyWindow.safeAreaInsets.top
        }
        let aLB = UILabel(frame: CGRect(x: hudLeft,
                                        y: -40.0,
                                        width: hudH * CGFloat(message.length),
                                        height: hudH))
//        aLB.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if let isError = isError, isError {//isError存在且值为true
            aLB.backgroundColor = UIColor(hexRGBValue: 0xf75356)
        }
        else {
            aLB.backgroundColor = UIColor(red:0.27, green:0.68, blue:0.49, alpha:1.00)//VUE绿
        }
        aLB.textColor = UIColor.white
        aLB.textAlignment = NSTextAlignment.center
        aLB.numberOfLines = 3
        aLB.font = UIFont.systemFont(ofSize: 12)
        aLB.text = "\(message)"
        aLB.tag = tag
        aLB.layer.masksToBounds = true
        aLB.layer.cornerRadius = 8
        aLB.alpha = 0.7
        UIApplication.shared.keyWindow?.addSubview(aLB)
        let size = aLB.getSize(constrainedWidth: width)

        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 25, options: [.curveEaseInOut,.beginFromCurrentState], animations: {
            aLB.frame = CGRect(x: hudLeft, y: hudH*2, width: size.width+30, height: hudH)

        }) { (complete) in

        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//            if cancelHide == false {
                aLB.removeFromSuperview()
//            }
        }
//        hud.mode = .text
//        hud.detailsLabel.text = message
//        hud.detailsLabel.font = UIFont.systemFont(ofSize: 18)
//        hud.bezelView.color = .black
//        hud.contentColor = .darkGray
//        hud.margin = 13
//        hud.removeFromSuperViewOnHide = true
//        UIApplication.shared.keyWindow?.addSubview(hud)
//        hud.show(animated: true)
//        hud.hide(animated: true, afterDelay: 1.5)
    }
    //MARK: 提示信息框
    class func showHUDText(message:String,view:UIView) -> Void {
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.mode = MBProgressHUDMode.text
        hud.detailsLabel.text = message
        hud.detailsLabel.font = UIFont.systemFont(ofSize: 18)
        hud.bezelView.color = .black
        hud.detailsLabel.textColor = .white
        hud.margin = 13
        hud.removeFromSuperViewOnHide = true
        hud.hide(animated: true, afterDelay: 1.5)
    }
    class func showBarProgress() {
        UIApplication.shared.keyWindow?.addSubview(shared.hud)
        shared.hud.mode = MBProgressHUDMode.determinateHorizontalBar
        shared.hud.show(animated: true)
    }
    class func updateBarProgress(_ progress: Float) {
        shared.hud.progress = progress
        if progress == 1 {
            shared.hud.hide(animated: true)
            shared.hud.progress = 0
        }
    }
    
    //MARK: 进度条
    /*
    func showWaitView(view:UIView)  {
        if waitHUb != nil {
            return
        }
        waitHUb = MBProgressHUD.init(view: view)
        waitHUb?.mode = MBProgressHUDMode.indeterminate
        waitHUb?.animationType = MBProgressHUDAnimation.zoomIn;
        waitHUb?.removeFromSuperViewOnHide = true
        //        waitHUb?.label.text = "Loading...";
        waitHUb?.label.textColor = UIColor.white;
        waitHUb?.bezelView.color = UIColor.black
//        if #available(iOS 9.0, *) {
        UIActivityIndicatorView.appearance(whenContainedInInstancesOf: [MBProgressHUD.self]).color = UIColor.white
//        } else {
//            waitHUb?.activityIndicatorColor = UIColor.white
//        }
        view.addSubview(waitHUb!)
        waitHUb?.show(animated: true)
    }
    
    func removeWaitView()  {
        waitHUb?.hide(animated: true, afterDelay: 0)
        waitHUb = nil
    }
    func doSomeWorkWithProgress(view:UIView) {
        canceled = false
        var progress: Float = 0.0
        while progress < 1.0 {
            if canceled {
                DispatchQueue.main.async(execute: {
                    self.deleteBGView.removeFromSuperview()
                })
                break
            }
            progress += 0.01
            DispatchQueue.main.async(execute: {
                self.annularView.progress = progress
            })
            usleep(50000) //50ms
        }
    }
    @objc func revoke() {
        canceled = true
    }
    @objc func aaa() {
        deleteBGView.removeFromSuperview()
    }
    
    func showDelayTaskHUD(completion: (() -> Void)? = nil) {
        let bottomPadding: CGFloat
        guard let keyWindow = UIApplication.shared.keyWindow else { return }
        let width = max(320, keyWindow.frame.width)
        if #available(iOS 11.0, *) {
            bottomPadding = UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
        } else {
            bottomPadding = 0
        }
        deleteBGView.frame = CGRect(x: 20, y: keyWindow.frame.size.height - 45 - bottomPadding, width: keyWindow.frame.size.width-40, height: 45)
        deleteBGView.backgroundColor = UIColor(white: 0, alpha: 0.8)
        UIApplication.shared.keyWindow?.addSubview(deleteBGView)
        deleteBGView.addSubview(annularView)
        annularView.frame = CGRect(x: 20, y: 10, width: 25, height: 25)
        
        deleteBGView.addSubview(revokeBtn)
        revokeBtn.frame = CGRect(x: deleteBGView.bounds.width - 15 - 60, y: 5, width: 60, height: 35)
        deleteBGView.addSubview(deleteLabel)

        
        DispatchQueue.global(qos: .default).async(execute: { [self] in
            doSomeWorkWithProgress(view: deleteBGView) //每隔50ms更新下进度条
            DispatchQueue.main.async(execute: { [self] in
                self.deleteBGView.removeFromSuperview()
//                if !canceled {
//                    if let completion = completion {
//                        completion()
//                    }
//                }
            })
        })
    }
    func showAlertInput(title:String,viewController:UIViewController,handler: ((UIAlertAction) -> Void)? = nil) {
        let alertController = UIAlertController(title: "修改文件（夹）名", message: "", preferredStyle: UIAlertController.Style.alert)
        alertController.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "输入文件名"
//            textField.text = fileObj.name
            textField.delegate = viewController as? UITextFieldDelegate
//            textField.tag = 233
        }
        let saveAction = UIAlertAction(title: "保存", style: UIAlertAction.Style.default, handler: handler)
        let cancelAction = UIAlertAction(title: "取消", style: UIAlertAction.Style.default, handler: nil)
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        viewController.present(alertController, animated: true, completion: nil)
    }
    
}


class PPAlertTool {
    class func showAction(title: String, message: String?, items: [String], callback: @escaping((_ index:Int)->())) {
        PPAlertAction.showSheet(withTitle: title, message: message, cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: items) { (index) in
            debugPrint("index===========",index)
            callback(index - 1)
        }
    }
}
