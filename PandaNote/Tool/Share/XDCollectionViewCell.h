//
//  XDCollectionViewCell.h
//  YiJian
//
//  Created by panway on 2018/8/21.
//  Copyright © 2018年 xiudian. All rights reserved.
//

#import <UIKit/UIKit.h>

static NSString *kXDCollectionViewCellReuseIdentifier = @"kXDCollectionViewCellReuseIdentifier";

@interface XDCollectionViewCell : UICollectionViewCell
- (void)xd_addSubviews;
/// 根据model更新界面，留给子类实现
- (void)updateUIWithData:(id)model;

@end
