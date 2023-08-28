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
@property (nonatomic, strong) NSMutableArray *dataSource2;
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
    UITableView *tableView = [UITableView new];
    [self addSubview:tableView];
    self.tableView = tableView;
    self.tableView.frame = CGRectMake(0, 0, PPScreenWidth, PPScreenHeight);
    
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    //这里的 H: 和 V: 分别代表水平和垂直方向的约束。而 | 符号表示父视图的边缘。因此，H:|[tableView]| 表示 tableView 的左边和右边都与父视图对齐，V:|[tableView]| 表示 tableView 的顶部和底部都与父视图对齐。

    //需要注意的是，在 Objective-C 中，字典的语法是用大括号 {} 括起来的键值对，因此在 views 参数中传递一个包含 tableView 的字典时，需要使用 @{@"tableView": tableView} 的语法。
    NSArray *constraints = @[
        @"H:|[tableView]|",
        @"V:|[tableView]|"
    ];

    for (NSString *constraint in constraints) {
        NSArray *format = [NSLayoutConstraint
            constraintsWithVisualFormat:constraint
                                options:0
                                metrics:nil
                                  views:@{@"tableView": tableView}];
        [self addConstraints:format];
    }


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
//    _dataSource = dataSource;
    _dataSource2 = [dataSource mutableCopy];
    [self.tableView reloadData];
}

- (NSArray *)dataSource {
    return _dataSource2;
}

/// MARK: Delegate
#pragma mark - UITableViewDataSource, UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource2.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PandaFastTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kXDFastTableViewCellReuseIdentifier];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    id model = self.dataSource2[indexPath.row];
    @try {
        [cell updateUIWithData:model];
    } @catch (NSException *exception) {
        
    } @finally {
        
    }
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

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // 先处理数据源
        [self.dataSource2 removeObjectAtIndex:indexPath.row];
        // 再删除 TableView 中的行
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        if(_didDeleteRowAtIndex) {
            _didDeleteRowAtIndex(indexPath.row);
        }
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
    if ([self isMemberOfClass:[PandaFastTableViewCell class]]) {
        self.textLabel.text = data;
    }
}
@end
