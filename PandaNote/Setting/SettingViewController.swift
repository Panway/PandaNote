//
//  SettingViewController.swift
//  PandaNote
//
//  Created by pan on 2026/2/9.
//  Copyright © 2026 Panway. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController {
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var appLockSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.addTarget(self, action: #selector(appLockSwitchChanged(_:)), for: .valueChanged)
        return switchControl
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemGroupedBackground
        } else {
            // Fallback on earlier versions
        }
        setupUI()
    }
    
    private func setupUI() {
        view.addSubview(stackView)
        
        // 第一行：开启应用锁
        let appLockRow = createSettingRow(title: "开启应用锁", accessoryView: appLockSwitch)
        stackView.addArrangedSubview(appLockRow)
        
        // 分割线
        let separator = createSeparator()
        stackView.addArrangedSubview(separator)
        
        // 第二行：清除缓存
        let clearCacheRow = createSettingRow(title: "清除缓存", accessoryView: nil)
        clearCacheRow.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(clearCache))
        clearCacheRow.addGestureRecognizer(tapGesture)
        stackView.addArrangedSubview(clearCacheRow)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    private func createSettingRow(title: String, accessoryView: UIView?) -> UIView {
        let container = UIView()
        if #available(iOS 13.0, *) {
            container.backgroundColor = .systemBackground
        } else {
            // Fallback on earlier versions
        }
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 50),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        if let accessoryView = accessoryView {
            accessoryView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(accessoryView)
            
            NSLayoutConstraint.activate([
                accessoryView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                accessoryView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
        }
        
        return container
    }
    
    private func createSeparator() -> UIView {
        let separator = UIView()
        if #available(iOS 13.0, *) {
            separator.backgroundColor = .separator
        } else {
            // Fallback on earlier versions
        }
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return separator
    }
    
    @objc private func appLockSwitchChanged(_ sender: UISwitch) {
        print("应用锁状态: \(sender.isOn ? "开启" : "关闭")")
    }
    
    @objc private func clearCache() {
        print("clear")
    }
}
