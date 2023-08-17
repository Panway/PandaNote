//
//  PPEditCloudServiceVC.swift
//  PandaNote
//
//  Created by Panway on 2023/3/31.
//  Copyright © 2023 Panway. All rights reserved.
//

import UIKit

class PPEditCloudServiceVC: PPBaseViewController {
    let table = XDFastTableView()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "编辑云服务"
        self.view.addSubview(table)
        table.snp.makeConstraints { (make) in
            make.top.equalTo(self.pp_safeLayoutGuideTop())
            make.left.right.bottom.equalToSuperview()
        }
        table.registerCellClass(PandaFastTableViewCell.self)
        let dataS = PPUserInfo.shared.pp_serverInfoList.map {(num) -> String in
            return "\(num["PPWebDAVRemark"] ?? "")"
            
        }
        table.dataSource = dataS
        table.didSelectRowAtIndexHandler = {(index: Int) ->Void in
            let dict = PPUserInfo.shared.pp_serverInfoList[index]
            
            print("click==\(index)")
            let vc = PPWebDAVConfigViewController()
            vc.isEditMode = true
            vc.editIndex = index
            vc.cloudType = dict["PPCloudServiceType"] ?? ""
            vc.extraString = dict["PPCloudServiceExtra"] ?? ""
            vc.accessToken = dict["PPAccessToken"] ?? ""
            
            vc.serverURL = dict["PPWebDAVServerURL"] ?? ""
            vc.showServerURL = vc.serverURL.length > 0

            vc.password = dict["PPWebDAVPassword"] ?? ""
            vc.showPassword = vc.password.length > 0
            
            vc.accessToken = dict["PPAccessToken"] ?? ""
            vc.showToken = vc.accessToken.length > 0
            
            vc.refreshToken = dict["PPRefreshToken"] ?? ""
            vc.showRefreshToken = vc.refreshToken.length > 0
            
            vc.userName = dict["PPWebDAVUserName"] ?? ""
            vc.showUserName = vc.userName.length > 0
            
            vc.remark = dict["PPWebDAVRemark"] ?? ""
            vc.showRemark = vc.remark.length > 0
            

            self.navigationController?.pushViewController(vc, animated: true)
        }
        table.didDeleteRowAtIndex = { index in
            debugPrint(index)
            if index == 0 {
                PPHUD.showHUDFromTop("暂不支持删除本地")
                return
            }
            PPUserInfo.shared.pp_serverInfoList.remove(at: index)
        }
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
