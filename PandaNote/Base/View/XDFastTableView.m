//
//  XDFastTableView.m
//  YiJian
//
//  Created by panwei on 2019/5/27.
//  Copyright © 2019 xiudian. All rights reserved.
//
#define PPScreenWidth [[UIScreen mainScreen] bounds].size.width
#define PPScreenHeight [[UIScreen mainScreen] bounds].size.height

#import "XDFastTableView.h"

@interface XDFastTableView ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic) BOOL cellDidRegister;

@end


@implementation XDFastTableView



- (instancetype)init {
    return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_addSubviews];
    }
    return self;
}

- (void)pp_addSubviews {
    self.itemHeight = 44.0;
    self.tableView = [UITableView new];
    [self addSubview:self.tableView];
    self.tableView.frame = CGRectMake(0, 0, PPScreenWidth, PPScreenHeight);
//    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make){
//        make.left.right.bottom.equalTo(self.view);
//        make.top.equalTo(self.view);
//    }];
    //    self.automaticallyAdjustsScrollViewInsets = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.tableFooterView = [UIView new];
//    self.tableView.separatorColor = XD_HEXCOLOR(0xeeeeee);
//    [self initDataSource];
//    self.tableView.backgroundColor = XD_HEXCOLOR(0xf5f5f5);

}
- (void)registerCellClass:(nullable Class)cellClass {
    [self.tableView registerClass:cellClass forCellReuseIdentifier:kXDFastTableViewCellReuseIdentifier];
    _cellDidRegister = YES;
}
- (void)setDataSource:(NSArray *)dataSource {
    if (!_cellDidRegister) {
        NSAssert(_cellDidRegister, @"Cell must be registered for identifier - %@", kXDFastTableViewCellReuseIdentifier);
        return;
    }
    _dataSource = dataSource;
    [self.tableView reloadData];
}

/// MARK: Delegate
#pragma mark - UITableViewDataSource, UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PandaFastTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kXDFastTableViewCellReuseIdentifier];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    id model = self.dataSource[indexPath.row];
    [cell updateUIWithData:model];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.itemHeight;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    if (_didSelectRowAtIndexHandler) {
        _didSelectRowAtIndexHandler(indexPath.row);
    }
}



/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end










@implementation PandaFastTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    // self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundView.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.backgroundColor = [UIColor clearColor];
    [self pp_addSubviews];
    return self;
}
- (void)pp_addSubviews {
    
}

- (void)updateUIWithData:(id)data {
    
}
@end
