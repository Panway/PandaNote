//
//  PPFloatingButton.swift
//  PandaNote
//
//  Created by pan on 2025/10/26.
//  Copyright © 2025 Panway. All rights reserved.
//

import UIKit
// 代码来自Claude:iOS开发中，使用UIButton和UIWindow写一个浮动的按钮，在任何UIViewController都能显示，点击按钮时动画扩展成一个小的UIView实现的面板，上面有个UILabel写着hello world
class PPFloatingButton {
    
    static let shared = PPFloatingButton()
    
    private var floatingWindow: UIWindow?
    private var floatingButton: UIButton!
    private var panelView: UIView!
    private var isPanelExpanded = false
    private var lastLocation: CGPoint = .zero
    
    private init() {
        setupFloatingWindow()
        setupFloatingButton()
        setupPanelView()
    }
    
    private func setupFloatingWindow() {
        floatingWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        floatingWindow?.windowLevel = .alert + 1
        floatingWindow?.backgroundColor = .clear
        floatingWindow?.rootViewController = UIViewController()
        floatingWindow?.rootViewController?.view.backgroundColor = .clear
        
        // 初始位置：右侧中间
        let screenHeight = UIScreen.main.bounds.height
        let screenWidth = UIScreen.main.bounds.width
        floatingWindow?.center = CGPoint(x: screenWidth - 40, y: screenHeight / 2)
    }
    
    private func setupFloatingButton() {
        floatingButton = UIButton(type: .custom)
        floatingButton.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        floatingButton.backgroundColor = .systemBlue
        floatingButton.layer.cornerRadius = 30
        floatingButton.layer.shadowColor = UIColor.black.cgColor
        floatingButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        floatingButton.layer.shadowOpacity = 0.3
        floatingButton.layer.shadowRadius = 4
        
        floatingButton.setTitle("+", for: .normal)
        floatingButton.titleLabel?.font = .systemFont(ofSize: 30, weight: .medium)
        
        floatingButton.addTarget(self, action: #selector(floatingButtonTapped), for: .touchUpInside)
        
        // 添加拖动手势
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        floatingButton.addGestureRecognizer(panGesture)
        
        floatingWindow?.rootViewController?.view.addSubview(floatingButton)
    }
    
    private func setupPanelView() {
        panelView = UIView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        panelView.backgroundColor = .white
        panelView.layer.cornerRadius = 30
        panelView.layer.shadowColor = UIColor.black.cgColor
        panelView.layer.shadowOffset = CGSize(width: 0, height: 2)
        panelView.layer.shadowOpacity = 0.3
        panelView.layer.shadowRadius = 8
        panelView.alpha = 0
        panelView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        
        let label = UILabel()
        label.text = "Hello World"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .darkText
        label.tag = 100
        panelView.addSubview(label)
        
        // 添加关闭按钮
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 20)
        closeButton.tag = 101
        closeButton.addTarget(self, action: #selector(closePanelTapped), for: .touchUpInside)
        panelView.addSubview(closeButton)
        
        floatingWindow?.rootViewController?.view.addSubview(panelView)
    }
    
    @objc private func floatingButtonTapped() {
        if isPanelExpanded {
            collapsePanel()
        } else {
            expandPanel()
        }
    }
    
    private func expandPanel() {
        isPanelExpanded = true
        
        // 禁用按钮交互
        floatingButton.isUserInteractionEnabled = false
        
        // 计算展开后的尺寸和位置
        let panelWidth: CGFloat = 200
        let panelHeight: CGFloat = 150
        let finalFrame = CGRect(
            x: (floatingWindow!.frame.width - panelWidth) / 2,
            y: (floatingWindow!.frame.height - panelHeight) / 2,
            width: panelWidth,
            height: panelHeight
        )
        
        // 保存 window 中心点
        guard let windowCenter = floatingWindow?.center else { return }
        
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: .curveEaseOut
        ) {
            // 隐藏按钮
            self.floatingButton.alpha = 0
            self.floatingButton.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            
            // 展开面板
            self.panelView.alpha = 1
            self.panelView.transform = .identity
            self.panelView.frame = finalFrame
            self.panelView.layer.cornerRadius = 12
            
            // 调整 window
            self.floatingWindow?.frame = CGRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
            self.floatingWindow?.center = windowCenter
            
        } completion: { _ in
            // 更新子视图布局
            if let label = self.panelView.viewWithTag(100) as? UILabel {
                label.frame = CGRect(x: 20, y: 50, width: panelWidth - 40, height: 30)
            }
            
            if let closeButton = self.panelView.viewWithTag(101) as? UIButton {
                closeButton.frame = CGRect(x: panelWidth - 40, y: 10, width: 30, height: 30)
            }
        }
    }
    
    private func collapsePanel() {
        isPanelExpanded = false
        
        guard let windowCenter = floatingWindow?.center else { return }
        
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: .curveEaseOut
        ) {
            // 收缩面板
            self.panelView.alpha = 0
            self.panelView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            
            // 显示按钮
            self.floatingButton.alpha = 1
            self.floatingButton.transform = .identity
            
            // 恢复 window 大小
            self.floatingWindow?.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
            self.floatingWindow?.center = windowCenter
            self.panelView.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
            
        } completion: { _ in
            self.floatingButton.isUserInteractionEnabled = true
        }
    }
    
    @objc private func closePanelTapped() {
        collapsePanel()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard !isPanelExpanded else { return } // 展开时不允许拖动
        
        let translation = gesture.translation(in: floatingWindow?.superview)
        
        switch gesture.state {
        case .began:
            lastLocation = floatingWindow?.center ?? .zero
            
        case .changed:
            let newCenter = CGPoint(
                x: lastLocation.x + translation.x,
                y: lastLocation.y + translation.y
            )
            floatingWindow?.center = newCenter
            
        case .ended:
            // 吸附到屏幕边缘
            snapToEdge()
            
        default:
            break
        }
    }
    
    private func snapToEdge() {
        let screenBounds = UIScreen.main.bounds
        let buttonRadius: CGFloat = 30
        let padding: CGFloat = 10
        
        guard let center = floatingWindow?.center else { return }
        var finalX = center.x
        var finalY = center.y
        
        // 水平方向吸附
        if center.x < screenBounds.width / 2 {
            finalX = buttonRadius + padding
        } else {
            finalX = screenBounds.width - buttonRadius - padding
        }
        
        // 垂直方向限制
        finalY = max(buttonRadius + padding + 44, finalY) // 顶部留空
        finalY = min(screenBounds.height - buttonRadius - padding - 34, finalY) // 底部留空
        
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: .curveEaseOut
        ) {
            self.floatingWindow?.center = CGPoint(x: finalX, y: finalY)
        }
    }
    
    func show() {
        floatingWindow?.isHidden = false
    }
    
    func hide() {
        floatingWindow?.isHidden = true
    }
}
