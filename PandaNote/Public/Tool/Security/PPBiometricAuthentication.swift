//
//  PPBiometricAuthentication.swift
//  PandaNote
//
//  Created by pan on 2024/2/1.
//  Copyright © 2024 Panway. All rights reserved.
//  使用LocalAuthentication框架写一个类，用来使用TouchID或面容ID解锁，并有一个回调闭包用来处理结果

import LocalAuthentication

class PPBiometricAuthentication {

    typealias AuthenticationCompletion = (Bool, Error?) -> Void

    private let context = LAContext()

    func authenticateWithBiometrics(completion: @escaping AuthenticationCompletion) {
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            completion(false, PPBiometricAuthenticationError.biometryNotAvailable)
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "使用 Touch ID 或 Face ID 解锁") { (success, error) in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
}

enum PPBiometricAuthenticationError: Error {
    case biometryNotAvailable
    case authenticationFailed
    case userCancel
    case userFallback
    case systemCancel
    case passcodeNotSet
    case biometryNotEnrolled
    case biometryLockout
    case appCancel
    case invalidContext
}

