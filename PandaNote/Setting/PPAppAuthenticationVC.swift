//
//  PPAppAuthenticationVC.swift
//  PandaNote
//
//  Created by pan on 2024/2/1.
//  Copyright © 2024 Panway. All rights reserved.
//

import Foundation

class PPAppAuthenticationVC : PPBaseViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let button = UIButton(type: .custom)
                button.addTarget(self, action: #selector(auth), for:.touchUpInside)
        self.view.addSubview(button)
        
        button.setTitle("点击验证你的面容ID\n或TouchID", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 22.0)
        button.titleLabel?.numberOfLines = 0
        button.backgroundColor = PPCOLOR_GREEN
        button.layer.cornerRadius = 6
        button.layer.masksToBounds = true
        
        button.snp.makeConstraints { make in
            make.top.equalTo(self.view).offset(88)
            make.left.equalTo(self.view).offset(50)
            make.right.equalTo(self.view).offset(-50)
        }
        
        auth()
    }
    @objc func auth() {
        let biometricAuth = PPBiometricAuthentication()
        biometricAuth.authenticateWithBiometrics { (success, error) in
            if success {
                // 验证成功
                print("Authentication successful")
                PPHUD.showHUDFromTop("验证成功")
                self.dismiss(animated: true)
                
            } else {
                // 验证失败，处理错误
                let errMsg = error?.localizedDescription ?? "Unknown error"
                print("Authentication failed: \(errMsg)")
                PPAlertAction.showAlert(withTitle: "生物识别失败", msg: errMsg, buttonsStatement: ["确定"], choose: nil)
            }
        }
    }
}
