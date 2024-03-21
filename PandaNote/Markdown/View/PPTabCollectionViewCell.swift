//
//  PPTabCollectionViewCell.swift
//  PandaNote
//
//  Created by pan on 2024/3/18.
//  Copyright © 2024 Panway. All rights reserved.
//

import UIKit

class PPTabCollectionViewCell: UICollectionViewCell {
    // 文字标签
    let label: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13.0)
//        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 关闭按钮
    let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(PPDrawIconView.iconImage(name: "x", width: 15, height: 15, color: PPCOLOR_GREEN), for: .normal)
        return button
    }()
    
    
    let bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hexRGBValue: 0xe5e5e5) //VSCode
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let rightLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hexRGBValue: 0xe5e5e5) //VSCode
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    var cellIndex = 0
    // 用于存储关闭按钮点击事件的回调闭包
    var closeButtonTappedHandler: ((_ index: Int) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // 添加子视图
        self.contentView.addSubview(label)
        self.contentView.addSubview(closeButton)
        self.contentView.addSubview(bottomLine)
        self.contentView.addSubview(rightLine)

        // UIKit自动布局AutoLayout设置约束
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
//            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -15),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
            closeButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
//            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor)

            bottomLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomLine.heightAnchor.constraint(equalToConstant: 1),
            bottomLine.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomLine.trailingAnchor.constraint(equalTo: trailingAnchor),

            rightLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            rightLine.heightAnchor.constraint(equalTo: heightAnchor),
            rightLine.widthAnchor.constraint(equalToConstant: 1),
            rightLine.bottomAnchor.constraint(equalTo: bottomAnchor),
            
        ])
        
        // 为关闭按钮添加点击事件
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
    }
    
    @objc func closeButtonTapped() {
        // 调用闭包，执行关闭按钮点击事件的处理
        closeButtonTappedHandler?(cellIndex)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
