//
//  ViewController+PPTool.swift
//  PandaNote
//
//  Created by panwei on 2020/4/4.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import Foundation
import SnapKit

extension UIViewController {
    
    func pp_safeLayoutGuideTop() -> ConstraintItem {
        if #available(iOS 11.0, *){
            //iOS11用安全区来当上边界
            return self.view.safeAreaLayoutGuide.snp.top
            //self.safeAreaLayoutGuide.leftAnchor
        }
        //self.leftAnchor
        return self.topLayoutGuide.snp.bottom
    }
    func pp_safeLayoutGuideBottom() -> ConstraintItem {
        if #available(iOS 11.0, *){
            //iOS11用安全区来当上边界
            return self.view.safeAreaLayoutGuide.snp.bottom
            //self.safeAreaLayoutGuide.leftAnchor
        }
        //self.leftAnchor
        return self.bottomLayoutGuide.snp.top
    }
    // 来源：https://stackoverflow.com/a/47094235/4493393
    /// 设置self.view的子视图挨着安全区
    /// - Parameter yourView: 子视图
    func pp_viewEdgeEqualToSafeArea(_ yourView:UIView) {
        yourView.snp.makeConstraints { (make) in
            if #available(iOS 11.0, *) {
                make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.margins)
//                //Bottom guide
//                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottomMargin)
//                //Top guide
//                make.top.equalTo(view.safeAreaLayoutGuide.snp.topMargin)
//                //Leading guide
//                make.leading.equalTo(view.safeAreaLayoutGuide.snp.leadingMargin)
//                //Trailing guide
//                make.trailing.equalTo(view.safeAreaLayoutGuide.snp.trailingMargin)
            } else {
                make.edges.equalToSuperview()
            }
        }
    }
}
