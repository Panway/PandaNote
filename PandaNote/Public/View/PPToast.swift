//
//  PPToast.swift
//  PandaNote
//
//  Created by pan on 2026/4/21.
//  Copyright © 2026 Panway. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Toast Manager

final class PPToast {
    // MARK: - Configuration

    struct PPToastConfig {
        var message: String
        var duration: TimeInterval = 2.0
        var position: Position = .bottom
        var style: Style = .dark

        enum Position {
            case top, center, bottom
        }

        enum Style {
            case dark, light, success, error, warning

            var backgroundColor: UIColor {
                switch self {
                case .dark: return UIColor.black.withAlphaComponent(0.85)
                case .light: return UIColor.white.withAlphaComponent(0.95)
                case .success: return UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 0.92)
                case .error: return UIColor(red: 0.95, green: 0.27, blue: 0.27, alpha: 0.92)
                case .warning: return UIColor(red: 1.00, green: 0.62, blue: 0.04, alpha: 0.92)
                }
            }

            var textColor: UIColor {
                switch self {
                case .light: return UIColor.black.withAlphaComponent(0.85)
                default: return .white
                }
            }

            var blurStyle: UIBlurEffect.Style {
                switch self {
                case .light: return .light
                default: return .dark
                }
            }
        }
    }

    // MARK: - Singleton

    static let shared = PPToast()
    private init() {}

    private weak var currentToastView: UIView?
    private var dismissWorkItem: DispatchWorkItem?

    // MARK: - Public API

    static func show(_ message: String,
                     duration: TimeInterval = 2.0,
                     position: PPToastConfig.Position = .bottom,
                     style: PPToastConfig.Style = .dark)
    {
        let config = PPToastConfig(message: message, duration: duration, position: position, style: style)
        shared.show(config: config)
    }

    static func dismiss() {
        shared.dismiss()
    }

    // MARK: - Core

    func show(config: PPToastConfig) {
        DispatchQueue.main.async {
            self.dismiss(animated: false)

            guard let window = UIWindow.keyWindowCompat else { return }

            let toastView = self.makeToastView(config: config)
            window.addSubview(toastView)
            self.layout(toastView: toastView, in: window, position: config.position)
            self.currentToastView = toastView

            // 动画进入
            toastView.alpha = 0
            toastView.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            UIView.animate(withDuration: 0.3,
                           delay: 0,
                           usingSpringWithDamping: 0.7,
                           initialSpringVelocity: 0.5,
                           options: .curveEaseOut,
                           animations: {
                               toastView.alpha = 1
                               toastView.transform = .identity
                           }, completion: nil)

            // 自动消失
            let workItem = DispatchWorkItem { [weak self] in
                self?.dismiss()
            }
            self.dismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + config.duration, execute: workItem)
        }
    }

    func dismiss(animated: Bool = true) {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        guard let toastView = currentToastView else { return }
        currentToastView = nil

        guard animated else {
            toastView.removeFromSuperview()
            return
        }

        UIView.animate(withDuration: 0.25,
                       delay: 0,
                       options: .curveEaseIn,
                       animations: {
                           toastView.alpha = 0
                           toastView.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
                       }, completion: { _ in
                           toastView.removeFromSuperview()
                       })
    }

    // MARK: - Private: Build View

    private func makeToastView(config: PPToastConfig) -> UIView {
        let container = UIView()
        container.backgroundColor = config.style.backgroundColor
        container.layer.cornerRadius = 12
        // layer.cornerCurve 是 iOS 13+，直接用默认圆角即可，iOS 11/12 无需设置
        container.clipsToBounds = true

        // 毛玻璃
        let blur = UIBlurEffect(style: config.style.blurStyle)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.alpha = 0.3
        blurView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(blurView)

        // Label
        let label = UILabel()
        label.text = config.message
        label.textColor = config.style.textColor
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: container.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])

        return container
    }

    // MARK: - Private: Layout

    private func layout(toastView: UIView, in window: UIWindow, position: PPToastConfig.Position) {
        toastView.translatesAutoresizingMaskIntoConstraints = false

        let safeTop = window.safeAreaInsetsCompat.top
        let safeBottom = window.safeAreaInsetsCompat.bottom

        var constraints: [NSLayoutConstraint] = [
            toastView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            toastView.widthAnchor.constraint(lessThanOrEqualTo: window.widthAnchor, constant: -80),
        ]

        switch position {
        case .top:
            constraints.append(
                toastView.topAnchor.constraint(equalTo: window.topAnchor, constant: safeTop + 16)
            )
        case .center:
            constraints.append(
                toastView.centerYAnchor.constraint(equalTo: window.centerYAnchor)
            )
        case .bottom:
            constraints.append(
                toastView.bottomAnchor.constraint(equalTo: window.bottomAnchor, constant: -(safeBottom + 60))
            )
        }

        NSLayoutConstraint.activate(constraints)
        window.layoutIfNeeded()
    }
}

// MARK: - UIWindow Compat

private extension UIWindow {
    /// 兼容 iOS 11 ~ iOS 17+ 获取 keyWindow
    static var keyWindowCompat: UIWindow? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }?
                .windows
                .first { $0.isKeyWindow }
        } else {
            // iOS 11 / 12
            return UIApplication.shared.keyWindow
        }
    }

    /// 兼容 iOS 11 获取 safeAreaInsets（iOS 11 才引入 safeAreaInsets，但 UIView 上有，UIWindow 也继承自 UIView，可直接用）
    /// 此处封装仅为语义清晰，实际 safeAreaInsets 在 iOS 11+ 均可用
    var safeAreaInsetsCompat: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return self.safeAreaInsets
        } else {
            return .zero
        }
    }
}
