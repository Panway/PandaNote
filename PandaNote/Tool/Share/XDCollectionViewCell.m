//
//  XDCollectionViewCell.m
//  YiJian
//
//  Created by panway on 2018/8/21.
//  Copyright © 2018年 xiudian. All rights reserved.
//

#import "XDCollectionViewCell.h"

@implementation XDCollectionViewCell
- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        [self xd_addSubviews];
    }
    return self;
}
- (void)xd_addSubviews {
    
}
- (void)updateUIWithData:(id)model {
}

@end
