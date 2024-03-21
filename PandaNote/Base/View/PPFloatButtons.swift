//
//  PPFloatButtons.swift
//  PandaNote
//
//  Created by pan on 2024/3/20.
//  Copyright © 2024 Panway. All rights reserved.
//

import Foundation
import Floaty

public protocol PPFloatButtonsDelegate: AnyObject {
    func didClickFloatButtons(title:String)
}


public class PPFloatButtons {
    var titles = [String]()
    weak var delegate: PPFloatButtonsDelegate?

    func showButtons(titles:[String], image:[String], containerView:UIView) {
        self.titles = titles
        let floaty = Floaty()
        floaty.isDraggable = true
        floaty.overlayColor = UIColor.black.withAlphaComponent(0.1)
        titles.enumerated().forEach { (index, title) in
            floaty.addItem(titles[index], icon: UIImage(named: image[index])!) { item in
                self.delegate?.didClickFloatButtons(title: item.title ?? "")
            }
        }
        containerView.addSubview(floaty)
    }
}
