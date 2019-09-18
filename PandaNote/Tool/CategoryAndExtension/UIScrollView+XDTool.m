//
//  UITableView+XDTool.m
//  YiJian
//
//  Created by panway on 2018/11/22.
//  Copyright © 2018 xiudian. All rights reserved.
//

#import "UIScrollView+XDTool.h"
#import <objc/runtime.h>
#import <MJRefresh/MJRefresh.h>
#import "XDRefreshAutoStateFooter.h"

@implementation UIScrollView (XDTool)
//二次封装，以后不用MJRefresh的话不用全局改了
- (void)addRefreshHeaderWithActionHandler:(void (^)(void))actionHandler {
    MJRefreshNormalHeader *header = [MJRefreshNormalHeader headerWithRefreshingBlock:^{
        if (actionHandler) {
            actionHandler();
        }
    }];
    self.mj_header = header;
    header.lastUpdatedTimeLabel.hidden = YES;
    [header setTitle:NSLocalizedString(@"下拉刷新", nil) forState:MJRefreshStateIdle];
    [header setTitle:NSLocalizedString(@"释放更新", nil) forState:MJRefreshStatePulling];
    [header setTitle:NSLocalizedString(@"加载中...", nil) forState:MJRefreshStateRefreshing];
    
    header.stateLabel.font = [UIFont systemFontOfSize:15];
}
- (void)addRefreshFooterWithActionHandler:(void (^)(void))actionHandler {
    self.mj_footer = [XDRefreshAutoStateFooter footerWithRefreshingBlock:^{
        if (actionHandler) {
            actionHandler();
        }
    }];
}
// 修改添加 开始刷新
-(void)beginRefreshing{
    [self.mj_header beginRefreshing];
}
- (void)endRefreshing {
    if ([self.mj_header isRefreshing]) {
        [self.mj_header endRefreshing];
    }
    if ([self.mj_footer isRefreshing]) {
        [self.mj_footer endRefreshing];
    }
}

- (void)noticeNoMoreData {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.mj_footer endRefreshingWithNoMoreData];
    });
}
- (void)setCurrentPage:(NSInteger)currentPage {
    currentPage = currentPage>0?currentPage:0;
    objc_setAssociatedObject(self, @selector(currentPage), @(currentPage), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)currentPage {
    NSNumber *currentPage = objc_getAssociatedObject(self, @selector(currentPage));
    return [currentPage integerValue];
}

@end
