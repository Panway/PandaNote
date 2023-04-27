//
//  PPBaseCollectionViewCell.swift
//  PandaNote
//
//  Created by Panway on 2022/7/2.
//  Copyright © 2022 WeirdPan. All rights reserved.
//

import UIKit

let kPPCollectionViewCellID = "kPPCollectionViewCellID"

class PPBaseCollectionViewCell: UICollectionViewCell {
    override init(frame: CGRect) {
        super.init(frame: frame)
        pp_addSubViews()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    //让子类重写
    func pp_addSubViews() {
        
    }
    //让子类重写
    func updateUIWithData(_ model:AnyObject)  {
        
    }
}
