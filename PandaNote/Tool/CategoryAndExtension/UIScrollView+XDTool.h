//
//  UITableView+XDTool.h
//  YiJian
//
//  Created by panway on 2018/11/22.
//  Copyright © 2018 xiudian. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIScrollView (XDTool)
///添加下拉刷新
- (void)addRefreshHeaderWithActionHandler:(void (^)(void))actionHandler;
///添加上拉加载更多
- (void)addRefreshFooterWithActionHandler:(void (^)(void))actionHandler;
// 修改添加 开始刷新
-(void)beginRefreshing;
/// 结束刷新
- (void)endRefreshing;
/// footer显示没有更多
- (void)noticeNoMoreData;
///动态创建tableView的页码属性（如果TableView数据有分页的话）
@property(nonatomic, assign) NSInteger currentPage;

@end

NS_ASSUME_NONNULL_END
