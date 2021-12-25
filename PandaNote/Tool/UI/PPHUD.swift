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
    
    static let shareInstance = PPHUD()
    
    var waitHUb:MBProgressHUD?
    //MARK: 顶部提示信息框
    class func showHUDFromTop(_ message:String, isError:Bool?=false) -> Void {
        let lastView = UIApplication.shared.keyWindow?.viewWithTag(9999)
        var lastViewExist = false
        if lastView != nil {
            lastViewExist = true
//            lastView?.removeFromSuperview()
        }
        let width = UIApplication.shared.keyWindow!.frame.width
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
        aLB.font = UIFont.systemFont(ofSize: 22)
        aLB.text = "\(message)"
        aLB.tag = 9999
        aLB.layer.masksToBounds = true
        aLB.layer.cornerRadius = 8
        UIApplication.shared.keyWindow?.addSubview(aLB)
        let size = aLB.getSize(constrainedWidth: width - 160)
        
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.76, initialSpringVelocity: 25, options: [.curveEaseInOut,.beginFromCurrentState], animations: {
            aLB.frame = CGRect(x: 80, y: lastViewExist ? 84 : 44.0, width: width-140, height: size.height + 20)

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
