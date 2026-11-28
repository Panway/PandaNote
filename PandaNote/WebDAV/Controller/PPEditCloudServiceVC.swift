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
            // 行号是照着数组生成的，理论上不会越界；挡一下是为了以后列表改成异步刷新时不至于直接崩
            guard index < PPUserInfo.shared.pp_serverInfoList.count else { return }
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
            
            vc.optCode = dict["PPOptCode"] ?? ""
            vc.showOtpCode = vc.cloudType == "synology"
            
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
            let info = PPUserInfo.shared
            // 删除回调里拿到的序号来自映射前的列表，中途刷新过就可能对不上，写操作前先挡一次越界
            guard index < info.pp_serverInfoList.count else { return }
            info.pp_serverInfoList.remove(at: index)

            // 删的是当前配置前面那条，当前配置整体前移一位。不动索引就会指向后一条配置，表现是明明在用 A，切到了 B
            if index < info.pp_lastSeverInfoIndex {
                info.selectServerIndex(info.pp_lastSeverInfoIndex - 1)
            }
            // 删的正好是当前配置：回落到本地，并且必须重建当前服务。
            // 只删数组不重建的话，PPUserInfo 里还留着已删配置的地址和类型，文件列表会继续对着一个不存在的服务发请求
            else if index == info.pp_lastSeverInfoIndex {
                info.selectServerIndex(0)
                PPFileManager.shared.initCloudServiceSetting()
                info.refreshFileList = true
            }
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
