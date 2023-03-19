//
//  PPPopMenu.swift
//  PandaNote
//
//  Created by Panway on 2023/3/5.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation
import PopMenu

class PPPopMenu: NSObject,PopMenuViewControllerDelegate {
    var controller : PopMenuViewController!
    var stringArray : Array<String>!
    var selectionAction: ((_ index : Int, _ string: String) -> ())?
    
    override init() {
        super.init()
        self.stringArray = []
    }
    
    
    func showWithCallback(sourceView: AnyObject? = nil,
                          stringArray:Array<String>,
                          sourceVC:UIViewController,
                          selectHandler:@escaping(_ index : Int, _ string: String) -> Void) {

        self.stringArray = stringArray
        var menuList = [PopMenuDefaultAction]()
        for item in stringArray {
            let item = PopMenuDefaultAction(title: item, image: nil, color: .darkText)
            menuList.append(item)
        }
        
        controller = PopMenuViewController(sourceView: sourceView, actions: menuList)
        
        // Customize appearance
        controller.appearance.popMenuFont = UIFont(name: "AvenirNext-DemiBold", size: 16)!
        controller.appearance.popMenuColor = PopMenuColor.configure(background: PopMenuActionBackgroundColor.solid(fill: PPCOLOR_GREEN), action: PopMenuActionColor.tint(UIColor.red))

//        controller.appearance.popMenuBackgroundStyle = .blurred(.dark)
        // Configure options
        controller.shouldDismissOnSelection = true//选择后是否自动消失
        controller.delegate = self
        controller.appearance.popMenuColor.backgroundColor = .solid(fill: .white)

        controller.didDismiss = { selected in
            print("Menu dismissed: \(selected ? "selected item" : "no selection")")
        }
        
        // Present menu controller
        sourceVC.present(controller, animated: true, completion: nil)
        self.selectionAction = selectHandler
    }
    
    func popMenuDidSelectItem(_ popMenuViewController: PopMenuViewController, at index: Int) {
//        debugPrint(index)
        self.selectionAction?(index, stringArray[index])
    }
}
