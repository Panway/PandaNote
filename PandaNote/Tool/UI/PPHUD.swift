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
class PPHUD: NSObject {
    
    static let shared = PPHUD()
    
    var waitHUb:MBProgressHUD?
    let deleteBGView = UIView()
    let annularView = MBRoundProgressView()
    var canceled = false
    
    lazy var revokeBtn : UIButton = {
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        button.setTitle("撤销", for: .normal)
        button.setTitleColor("#3eaf7c".pp_HEXColor(), for: .normal) // #4abf8a 浅色
//        button.setImage(UIImage(named: "revoke"), for: .normal)
        button.addTarget(self, action: #selector(revoke), for: .touchUpInside)
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
        let lastView = UIApplication.shared.keyWindow?.viewWithTag(9999)
        var lastViewExist = false
        if lastView != nil {
            lastViewExist = true
//            lastView?.removeFromSuperview()
        }
        let width = UIApplication.shared.keyWindow?.frame.width ?? 400
        let aLB = UILabel(frame: CGRect(x: 80, y: -40.0, width: width-160, height: 140.0))
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
        aLB.font = UIFont.systemFont(ofSize: 16)
        aLB.text = "\(message)"
        aLB.tag = 9999
        aLB.layer.masksToBounds = true
        aLB.layer.cornerRadius = 8
        aLB.alpha = 0.7
        UIApplication.shared.keyWindow?.addSubview(aLB)
        let size = aLB.getSize(constrainedWidth: width - 160)
        
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.76, initialSpringVelocity: 25, options: [.curveEaseInOut,.beginFromCurrentState], animations: {
            aLB.frame = CGRect(x: 80, y: lastViewExist ? 84 : 44.0, width: width-140, height: size.height + 10)

        }) { (complete) in
            
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            aLB.removeFromSuperview()
        }
//        hud.mode = MBProgressHUDMode.text
//        hud.detailsLabel.text = message
//        hud.detailsLabel.font = UIFont.systemFont(ofSize: 18)
//        hud.bezelView.color = UIColor.black
//        hud.detailsLabel.textColor = UIColor.white
//        hud.margin = 13
//        hud.removeFromSuperViewOnHide = true
//        hud.hide(animated: true, afterDelay: 1.5)
    }
    //MARK: 提示信息框
    class func showHUDText(message:String,view:UIView) -> Void {
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.mode = MBProgressHUDMode.text
        hud.detailsLabel.text = message
        hud.detailsLabel.font = UIFont.systemFont(ofSize: 18)
        hud.bezelView.color = UIColor.black
        hud.detailsLabel.textColor = UIColor.white
        hud.margin = 13
        hud.removeFromSuperViewOnHide = true
        hud.hide(animated: true, afterDelay: 1.5)
    }
    
    //MARK: 进度条
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
        if #available(iOS 11.0, *) {
            bottomPadding = UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
        } else {
            bottomPadding = 0
        }
        deleteBGView.frame = CGRect(x: 20, y: UIScreen.main.bounds.height - 45 - bottomPadding, width: UIScreen.main.bounds.width-40, height: 45)
        deleteBGView.backgroundColor = UIColor(white: 0, alpha: 0.8)
        UIApplication.shared.keyWindow?.addSubview(deleteBGView)
        deleteBGView.addSubview(annularView)
        annularView.frame = CGRect(x: 20, y: 10, width: 25, height: 25)
        
        deleteBGView.addSubview(revokeBtn)
        revokeBtn.frame = CGRect(x: deleteBGView.bounds.width - 15 - 60, y: 5, width: 60, height: 35)
        deleteBGView.addSubview(deleteLabel)

        
        DispatchQueue.global(qos: .default).async(execute: { [self] in
            doSomeWorkWithProgress(view: deleteBGView)
            DispatchQueue.main.async(execute: {
                deleteBGView.removeFromSuperview()
                if !canceled {
                    if let completion = completion {
                        completion()
                    }
                }
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
