//
//  XDFastTableView.h
//  YiJian
//
//  Created by panwei on 2019/5/27.
//  Copyright © 2019 xiudian. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
static NSString *kXDFastTableViewCellReuseIdentifier = @"kXDFastTableViewCellReuseIdentifier";

@interface XDFastTableView : UIView
/// 数据源（里面放Model）
@property (nonatomic, strong) NSArray *dataSource;
@property (nonatomic, strong) UITableView *tableView;
/// Item高度（垂直方向排列时）
@property(nonatomic) NSInteger itemHeight;
- (void)registerCellClass:(nullable Class)cellClass;
- (void)pp_addSubviews;
/// 选中某Item的回调block
@property (nonatomic, copy) void(^didSelectRowAtIndexHandler)(NSInteger index);

@end










@interface PandaFastTableViewCell : UITableViewCell
@property (nonatomic, strong) id model;
- (void)pp_addSubviews;
- (void)updateUIWithData:(id)data;

@end
NS_ASSUME_NONNULL_END
