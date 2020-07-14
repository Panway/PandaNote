//
//  XDShareView.m
//  DrawShareImage
//
//  Created by wangchao on 2018/7/4.
//  Copyright © 2018年 Panwei. All rights reserved.
//
#import <UIKit/UIKit.h>

#define PPScreenWidth [[UIScreen mainScreen] bounds].size.width
#define PPScreenHeight [[UIScreen mainScreen] bounds].size.height
#define weakify(var) __weak typeof(var) AHKWeak_##var = var;

#define PPIconW 50
#define pp_navbar_height 44
#define itemsViewH 180

static inline BOOL isiPhoneXSeries() {
    static dispatch_once_t once;
    //    static SInt32 FMDBVersionVal = 0;
    static BOOL iPhoneXSeries = NO;
    
    dispatch_once(&once, ^{
        if (@available(iOS 11.0, *)) {
            UIWindow *mainWindow = [[[UIApplication sharedApplication] delegate] window];
            if (mainWindow.safeAreaInsets.bottom > 0.0) {
                iPhoneXSeries = YES;
            }
        }
        
    });
    return iPhoneXSeries;
}


#define XD_ISIPHONE_X isiPhoneXSeries()
#define XD_BOTTOM_PADDING (XD_ISIPHONE_X?34.0:0)

///将16进制的颜色数字转为RGB
#define XD_HEXCOLOR(hexNum) [UIColor colorWithRed:((hexNum>>16)&0xFF)/255.0f green:((hexNum>>8)&0xFF)/255.0f blue:(hexNum&0xFF)/255.0f alpha:1.0f]

#import "PPShareManager.h"
//#import "XDUIHeader.h"

//#import <TencentOpenAPI/TencentOAuth.h>


///判断SDWebImage是否可用,可用的话就优先使用它取缓存
#if __has_include(<SDWebImage/SDWebImageManager.h>)
#import <SDWebImage/SDWebImageManager.h>
#define USE_SDWebImage 1
#else
#define USE_SDWebImage 0
#endif


@interface XDShareView ()<GBHorizontalItemViewDelegate>
{
//    NSArray *_dataSource;
    UIView *_contentView;
    CGFloat _statusBarHeight;
    XDHorizontalItemView *_itemsView;
}

@end
@implementation XDShareView
- (id)init {
    return [self initWithFrame:CGRectMake(0.0f, 0.0f, 220.0f, 110.0f)];
}
- (void)dealloc {
//    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self addTarget:self action:@selector(dismissView) forControlEvents:UIControlEventTouchUpInside];
        _contentView = [UIView new];
        [self addSubview:_contentView];
        _contentView.backgroundColor = [UIColor whiteColor];
        _statusBarHeight = XD_ISIPHONE_X?44:20;
        
        _itemsView = [[XDHorizontalItemView alloc] initWithFrame:CGRectMake(0, 10, PPScreenWidth, itemsViewH/2) scrollDirection:UICollectionViewScrollDirectionVertical];
        [_contentView addSubview:_itemsView];
        _itemsView.backgroundColor = [UIColor whiteColor];
        _itemsView.itemHeight = itemsViewH/2;
        _itemsView.maxItemCountInScreen = 5;
        _itemsView.bounces = NO;
        _itemsView.delegate = self;
        _itemsView.dataSource = @[@{@"icon":@"share_weixin_image",@"text":@"微信"},
                                  @{@"icon":@"share_pengyouquan_image",@"text":@"朋友圈"},
                                  @{@"icon":@"share_qq_image",@"text":@"QQ"},
                                  @{@"icon":@"share_qqkongjian_image",@"text":@"QQ空间"},
                                  @{@"icon":@"share_sina_image",@"text":@"新浪微博"}
                                  ];
//        GBWeak(self);
        __weak typeof(self) weakSelf = self;
        [_itemsView setRegisterCellClass:^{
            __typeof__(self) strongSelf = weakSelf;
            [strongSelf->_itemsView.collectionView registerClass:[XDShareCollectionViewCell class] forCellWithReuseIdentifier:kHorizontalItemView];
        }];

        [_itemsView reloadDataSource];
        
        UIView *line = [[UIView alloc] init];
        line.frame = CGRectMake(0,130 - 1,PPScreenWidth,0.6);
        line.layer.backgroundColor = [UIColor colorWithRed:238/255.0 green:238/255.0 blue:238/255.0 alpha:1.0].CGColor;
        [_contentView addSubview:line];
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button addTarget:self
                   action:@selector(dismissView)
         forControlEvents:UIControlEventTouchUpInside];
        [button setTitle:@"取消" forState:UIControlStateNormal];
        [button setTitleColor:XD_HEXCOLOR(0x333333) forState:UIControlStateNormal];
        button.frame = CGRectMake(0, 130, PPScreenWidth, 50);
        [_contentView addSubview:button];
        
        NSLog(@"====%@",@(USE_SDWebImage));
    }
    return self;
}

- (void)didSelectItemAtIndex:(NSInteger)index withData:(id)dataModel {
//    NSLog(@"====%@",@(index));
    // https://img.alicdn.com/tfs/TB1atJ5D4SYBuNjSspjXXX73VXa-692-552.png  221KB
    // https://qny.smzdm.com/201710/27/59f300bfca5687817.jpg_d200.jpg
    NSString *title = [PPShareManager sharedManager].title;
    NSString *content = [PPShareManager sharedManager].content;
    NSString *url = [PPShareManager sharedManager].url;
    id image = [PPShareManager sharedManager].image;
    [[PPShareManager sharedManager] shareWithTitle:title content:content url:url image:image platform:index completion:^(NSString *resultMsg) {
        NSLog(@"====%@",resultMsg);
        [PPShareManager sharedManager].shareOriginImage = NO;
    }];
    [self dismissView];
    
}

- (void)showInView:(UIView *)superView backgroundAlpha:(CGFloat)alpha animated:(BOOL)animated {
    CGFloat screenWidth = PPScreenWidth;
    CGFloat screenHeight1 = PPScreenHeight;
    
    self.frame = CGRectMake(0, 0, screenWidth, screenHeight1);
    [superView addSubview:self];
    self.backgroundColor = [UIColor colorWithWhite:0.f alpha:0.3f];
//    NSAssert(_dataSource.count > 0, @"dataSource 要在显示前配置好");
    _contentView.frame = CGRectMake(0, PPScreenHeight, screenWidth, 100);
//    [self updateSubViewsFrame:_contentView.frame];
    if (animated) {
        NSTimeInterval _animationDuration = .25;
        
        [UIView animateWithDuration:_animationDuration delay:0.0 usingSpringWithDamping:0.7 initialSpringVelocity:5.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self->_contentView.frame = CGRectMake(0, PPScreenHeight - (itemsViewH+XD_BOTTOM_PADDING), screenWidth, itemsViewH+XD_BOTTOM_PADDING);

        } completion:^(BOOL finished) {
            
        }];
    }
    
}

- (void)showInView:(UIView *)superView animated:(BOOL)animated {
    [self showInView:superView backgroundAlpha:0 animated:animated];
}

- (void)showInView:(UIView *)superView {
    [self showInView:superView animated:YES];
}

- (void)show {
    [self showInView:[UIApplication sharedApplication].keyWindow];
}

-(void)dismissView{
    if (_clickDismissView) {
        _clickDismissView();
    }
    [self removeFromSuperview];
}

@end


#pragma mark - PPShareManager

#if PP_USE_WECHAT_SHARE
@interface PPShareManager ()<WXApiDelegate>
#else
@interface PPShareManager ()

#endif
@end
//
@implementation PPShareManager

+ (nonnull instancetype)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
//        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleShareResult:) name:@"XDHandleShareResult" object:nil];
    });
    return instance;
}
//- (void)handleShareResult:(NSNotification *)notification {
//    NSLog(@"====%@",notification.object);
//    if (_shareHandler) {
//        _shareHandler(@"666");
//    }
//}
- (void)shareWithTitle:(NSString *)title content:(NSString *)content url:(NSString *)url image:(id)image platform:(PPSharePlatform)platform completion:(void (^)(NSString * resultMsg))completion {
    if (platform == PPSharePlatformWeixinSession||platform == PPSharePlatformWeixinTimeline) {
#if PP_USE_WECHAT_SHARE
        if (_shareOriginImage) {
            [self weixinShareImage:image type:platform];
        }
        else {
            [[PPShareManager sharedManager] weixinShareLinkWithUrl:url title:title description:content image:image type:platform];
        }
#else
#endif
    }
    else if (platform == PPSharePlatformWeibo) {
#if PP_USE_WEIBO_SHARE
        [[PPShareManager sharedManager] weiboShareLinkWithUrl:url title:title description:content image:image];
#else
#endif
    }
    else if (platform == PPSharePlatformQQSession || platform == PPSharePlatformQZone) {
#if PP_USE_QQ_SHARE
        [[PPShareManager sharedManager] qqShareLinkWithUrl:url title:title description:content image:image type:platform];
#else
#endif
    }
    else if (platform == PPSharePlatformClipboard) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        [pasteboard setString:url];
        if ([PPShareManager sharedManager].shareHandler) {
            [PPShareManager sharedManager].shareHandler(@"链接已复制到剪切板");
        }
    }
    else if (platform == PPSharePlatformImage) {
        UIImage *saveImg = [self shareImageWithTitle:title content:content url:url imageURL:[PPShareManager sharedManager].originalImageURL price:998.0 size:CGSizeMake(414*2, 700*2)];
        UIImageWriteToSavedPhotosAlbum(saveImg, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    }
//    self.shareHandler = completion;
//    [self dismissView];
}




- (NSData *)getImageDataWithImageOrURL:(id)image {
    UIImage *distImage = nil;

    if ([image isKindOfClass:[UIImage class]]) {
        NSData *myData = [self compressToSize:30 data:UIImagePNGRepresentation(image)];
        return myData;
    }
    else if ([image isKindOfClass:[NSString class]]) {
#if USE_SDWebImage
        distImage = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:image];
#endif
        if (distImage) {
            NSData *myData = [self compressToSize:30 data:UIImagePNGRepresentation(distImage)];
            return myData;
        } else {
            NSData *myData = [NSData dataWithContentsOfURL:[NSURL URLWithString:image]];
#if USE_SDWebImage
            [[SDWebImageManager sharedManager] loadImageWithURL:[NSURL URLWithString:image] options:0 progress:NULL completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, SDImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
            }];
#endif
            myData = [self compressToSize:30 data:myData];
            return myData;
        }
    }
    return nil;
}

- (UIImage *)getUIImageWithImageOrURL:(id)image {
    return [UIImage imageWithData:[self getImageDataWithImageOrURL:image]];
}
- (NSData *)compressToSize:(NSInteger)expectedSizeInMb data:(NSData *)Data {
    CGFloat sizeInBytes = expectedSizeInMb * 1024;
//    NSData * imgData = Data;
    UIImage *newImage1 = [UIImage imageWithData:Data];

    CGFloat compressingValue = 0.9;
    if (Data.length > sizeInBytes) {
        newImage1 = [self imageByResizeToMinSize:CGSizeMake(100, 100) image:newImage1];
    }
    NSData *newData = UIImagePNGRepresentation(newImage1);
    BOOL needCompress = newData.length > sizeInBytes;

    while (needCompress && compressingValue > 0.1) {
        newData = UIImageJPEGRepresentation(newImage1, compressingValue);
        if (newData.length < sizeInBytes) {
            needCompress = NO;
            newImage1 = [UIImage imageWithData:newData];
        }
        else {
            compressingValue -= 0.1;
        }
    }
    return newData;
}
/// 等比缩放 限制最大宽高100
- (UIImage *)imageByResizeToMinSize:(CGSize)size image:(UIImage *)image {
    if (size.width <= 0 || size.height <= 0) return nil;
    float actualHeight = image.size.height;
    float actualWidth = image.size.width;
    //宽或高大于1280才等比缩小裁剪，不然图像失真严重
    float maxHeight = size.width;
    float maxWidth = size.height;
    float imgRatio = actualWidth/actualHeight;
    float maxRatio = maxWidth/maxHeight;
//    float compressionQuality = 0.5;//50 percent compression
    
    if (actualHeight > maxHeight || actualWidth > maxWidth){
        if(imgRatio < maxRatio){
            //adjust width according to maxHeight
            imgRatio = maxHeight / actualHeight;
            actualWidth = imgRatio * actualWidth;
            actualHeight = maxHeight;
        }
        else if(imgRatio > maxRatio){
            //adjust height according to maxWidth
            imgRatio = maxWidth / actualWidth;
            actualHeight = imgRatio * actualHeight;
            actualWidth = maxWidth;
        }
        else{
            actualHeight = maxHeight;
            actualWidth = maxWidth;
        }
    }

    CGRect rect = CGRectMake(0,0,actualWidth,actualHeight);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, [UIScreen mainScreen].scale);
    [image drawInRect:rect];
    UIImage *picture1 = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return picture1;
}
+ (UIImage *)pp_ImageWithColor:(UIColor *)color {
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    //    UIGraphicsBeginImageContextWithOptions(rect.size, NO, [[UIScreen mainScreen] scale]);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}
#pragma mark 返回应用scheme处理
- (BOOL)handleOpenURL:(NSURL *)url {
    NSLog(@"====%@",url.absoluteString);
#if PP_USE_WEIBO_SHARE
    if ([url.absoluteString hasPrefix:@"wb"]) {
        return [WeiboSDK handleOpenURL:url delegate:self];
    }
#else
#endif
    
#if PP_USE_WECHAT_SHARE
    if ([url.absoluteString hasPrefix:@"wx"]) {
        return [WXApi handleOpenURL:url delegate:self];
    }
#else
#endif
//    else if ([url.absoluteString hasPrefix:@"tencent"]) {
//        return [QQApiInterface handleOpenURL:url delegate:(id<QQApiInterfaceDelegate>)[PPShareManager class]];
//    }
    return NO;
}

#pragma mark - 微信 WXApiDelegate
#if PP_USE_WECHAT_SHARE

+ (void)initWeixinAppId:(NSString *)appId appKey:(NSString *)appKey {
    [WXApi registerApp:appId universalLink:@""];
    //    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    //        //构造SendAuthReq结构体
    //        SendAuthReq* req = [[SendAuthReq alloc]init];
    //        req.scope = @"snsapi_userinfo";
    //        req.state = @"123";
    //        //第三方向微信终端发送一个SendAuthReq消息结构
    //        [WXApi sendReq:req];
    //    });
}
- (void)weixinShareLinkWithUrl:(NSString *)url title:(NSString *)title description:(NSString *)description image:(id)image type:(NSInteger)type {
    WXMediaMessage *message = [WXMediaMessage message];
    message.title = title;
    message.description = description;
    [message setThumbImage:[self getUIImageWithImageOrURL:image]];
    
    WXWebpageObject *ext = [WXWebpageObject object];
    ext.webpageUrl = url;
    
    message.mediaObject = ext;
    
    SendMessageToWXReq* req = [[SendMessageToWXReq alloc] init];
    req.bText = NO;
    req.message = message;
    req.scene = type == PPSharePlatformWeixinSession?WXSceneSession:WXSceneTimeline;
    [WXApi sendReq:req completion:^(BOOL success) {
        
    }];
}
- (void)weixinShareImage:(UIImage *)image type:(NSInteger)type {
    NSData *imageData = UIImageJPEGRepresentation(image, 0.9);
    
    WXImageObject *imageObject = [WXImageObject object];
    imageObject.imageData = imageData;
    
    WXMediaMessage *message = [WXMediaMessage message];
    message.thumbData = [self getImageDataWithImageOrURL:[PPShareManager pp_ImageWithColor:[UIColor whiteColor]]];
    message.mediaObject = imageObject;
    
    SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
    req.bText = NO;
    req.message = message;
    req.scene = type == PPSharePlatformWeixinSession?WXSceneSession:WXSceneTimeline;
    [WXApi sendReq:req completion:^(BOOL success) {
        
    }];
}
- (void)weixinShareEmoji:(NSData *)emoji type:(NSInteger)type {
    WXMediaMessage *message = [WXMediaMessage message];
    [message setThumbImage:[PPShareManager pp_ImageWithColor:[UIColor whiteColor]]];
    
    WXEmoticonObject *ext = [WXEmoticonObject object];
//    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"res6" ofType:@"gif"];
    ext.emoticonData = emoji;//[NSData dataWithContentsOfFile:filePath] ;
    
    message.mediaObject = ext;
    
    SendMessageToWXReq* req = [[SendMessageToWXReq alloc] init];
    req.bText = NO;
    req.message = message;
    req.scene = type == PPSharePlatformWeixinSession?WXSceneSession:WXSceneTimeline;
    
    [WXApi sendReq:req completion:^(BOOL success) {
        
    }];
}
-(void)onReq:(BaseReq*)req {
    // just leave it here, WeChat will not call our app
    NSLog(@"====%@",req);
}

-(void)onResp:(BaseResp*)resp {
    if([resp isKindOfClass:[SendMessageToWXResp class]]) {
//        SendMessageToWXResp * sendMessageResp = (SendMessageToWXResp*)resp;
        NSString *success = @"分享成功";
        switch (resp.errCode) {
            case WXSuccess:{
                 NSLog(@"微信分享成功");
//                NSLog(@"RESP:code:%@,state:%@\n", sendMessageResp.errCode, sendMessageResp.state);
                break;
            }
            case WXErrCodeAuthDeny: {
                
                break;
            }
            case WXErrCodeUserCancel:{
                success = @"分享已取消";
                NSLog(@"微信分享已取消");
                break;
            }
            default:
                break;
        }
        if ([PPShareManager sharedManager].shareHandler) {
            [PPShareManager sharedManager].shareHandler(success);
        }
    }
    else if([resp isKindOfClass:[SendAuthResp class]]) {
        SendAuthResp *authResp = (SendAuthResp *)resp;
        NSLog(@"授权登录Code====%@",authResp.code);
        if ([PPShareManager sharedManager].loginHandler) {
            [PPShareManager sharedManager].loginHandler(@{@"code":authResp.code});
        }
    }
}
#else
#endif
#pragma mark  微博
#if PP_USE_WEIBO_SHARE

+ (void)initWeiboAppId:(NSString *)appId appKey:(NSString *)appKey {
    [WeiboSDK registerApp:appId];
}

- (void)weiboShareLinkWithUrl:(NSString *)url title:(NSString *)title description:(NSString *)description image:(id)image {
    NSLog(@"调用了微博");
    WBAuthorizeRequest *authRequest = [WBAuthorizeRequest request];
    authRequest.redirectURI = @"https://api.weibo.com/oauth2/default.html";
    authRequest.scope = @"all";
    
    WBMessageObject *message = [WBMessageObject message];
    
    //设置分享的标题
    message.text = [NSString stringWithFormat:@"%@ %@ %@",description,title,url];
    
    WBImageObject *imageObject = [WBImageObject object];
//    imageObject.delegate = self;
    if (_shareOriginImage) {
        message.text = @"";
        imageObject.imageData = UIImageJPEGRepresentation(image, 0.9);
    }
    else {
        imageObject.imageData = [self getImageDataWithImageOrURL:image];
    }
    message.imageObject = imageObject;
    
    WBSendMessageToWeiboRequest *request = [WBSendMessageToWeiboRequest requestWithMessage:message authInfo:authRequest access_token:nil];
    request.userInfo = @{@"ShareMessageFrom": @"SendMessageToWeiboViewController",
                         @"Other_Info_1": [NSNumber numberWithInt:123],
                         @"Other_Info_2": @[@"obj1", @"obj2"],
                         @"Other_Info_3": @{@"key1": @"obj1", @"key2": @"obj2"}};
    //调用此方法进行分享
    [WeiboSDK sendRequest:request];
}
- (void)didReceiveWeiboResponse:(WBBaseResponse *)response {
    if ([response isKindOfClass:WBSendMessageToWeiboResponse.class])
    {
//        NSString *message = [NSString stringWithFormat:@"%@: %d\n%@: %@\n%@: %@", NSLocalizedString(@"响应状态", nil), (int)response.statusCode, NSLocalizedString(@"响应UserInfo数据", nil), response.userInfo, NSLocalizedString(@"原请求UserInfo数据", nil),response.requestUserInfo];
//        NSLog(@"didReceiveWeiboResponse\n\n====%@\n\n",message);
        NSString *success = @"分享成功";
        if (response.statusCode == WeiboSDKResponseStatusCodeUserCancel) {
            success = @"分享已取消";
            NSLog(@"微博分享已取消");
        }
        else if (response.statusCode == WeiboSDKResponseStatusCodeSuccess) {
            NSLog(@"微博分享成功");
        }
        if ([PPShareManager sharedManager].shareHandler) {
            [PPShareManager sharedManager].shareHandler(success);
        }
    }
}

- (void)didReceiveWeiboRequest:(WBBaseRequest *)request {
    
}
#else
#endif

#pragma mark QQ
#if PP_USE_QQ_SHARE


+ (void)initQQAppId:(NSString *)appId appKey:(NSString *)appKey {
    (void)[[TencentOAuth alloc] initWithAppId:appId andDelegate:(id)self];
}
- (void)qqShareLinkWithUrl:(NSString *)url title:(NSString *)title description:(NSString *)description image:(id)image type:(NSInteger)type {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    if ([[url stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] isEqualToString:url]) {
        url = [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];//防止二次encode
    }
#pragma clang diagnostic pop
    QQApiNewsObject *newsObj;
    if ([image isKindOfClass:[UIImage class]]) {
        /// 大坑：如果plist文件不加 `<string>mqqopensdkapiV2</string>`的话 图片不显示！！！
        NSData *imgData = [self getImageDataWithImageOrURL:image];
        if (_shareOriginImage) {
            NSData *imageData = UIImageJPEGRepresentation(image, 0.9);
            newsObj = [QQApiImageObject objectWithData:imageData previewImageData:imgData title:@"亿健运动" description:@"运动分享"];//title 和 description不会显示

        }
        else {
        newsObj = [QQApiNewsObject objectWithURL:[NSURL URLWithString:url ? : @""]
                                           title:title ? : @""
                                     description:description ? : @""
                                previewImageData:imgData];
        }
    }
    else if ([image isKindOfClass:[NSString class]]) {
        newsObj = [QQApiNewsObject objectWithURL:[NSURL URLWithString:url ? : @""]
                                                            title:title ? : @""
                                                      description:description ? : @""
                                                 previewImageURL:[NSURL URLWithString:image]];
    }
    SendMessageToQQReq *req = [SendMessageToQQReq reqWithContent:newsObj];
    QQApiSendResultCode ret = 0;
    if (type == 2) {
        //分享给QQ好友
        ret = [QQApiInterface sendReq:req];
    }
    else if (type == 3) {
        //分享给QQ空间
        ret = [QQApiInterface SendReqToQZone:req];
    }
    [self handleSendResult:ret];
}
///QQ分享回调
+ (void)onResp:(QQBaseResp *)resp {
    switch (resp.type) {
        case ESENDMESSAGETOQQRESPTYPE: {
            SendMessageToQQResp* sendReq = (SendMessageToQQResp*)resp;
            NSString *success = @"分享成功";
            if ([sendReq.result integerValue] == 0) {
                NSLog(@"QQ分享成功");
            }
            else if ([sendReq.result integerValue] == -4) {
                success = @"分享已取消";
                NSLog(@"QQ分享已取消");
            }
            if ([PPShareManager sharedManager].shareHandler) {
                [PPShareManager sharedManager].shareHandler(success);
            }
            break;
        }
        default: {
            break;
        }
    }
}
///打开手机QQ的结果
- (void)handleSendResult:(QQApiSendResultCode)sendResult {
    switch (sendResult) {
        case EQQAPIAPPNOTREGISTED: {
            NSLog(@"App未注册");
            break;
        }
        case EQQAPIMESSAGECONTENTINVALID:
        case EQQAPIMESSAGECONTENTNULL:
        case EQQAPIMESSAGETYPEINVALID: {
            NSLog(@"发送参数错误");
            break;
        }
        case EQQAPIQQNOTINSTALLED: {
            NSLog(@"未安装手Q");
            break;
        }
        case EQQAPIQQNOTSUPPORTAPI: {
            NSLog(@"手Q API接口不支持");
            break;
        }
        case EQQAPISENDFAILD: {
            NSLog(@"发送失败");
            break;
        }
        case EQQAPIQZONENOTSUPPORTTEXT: {
            NSLog(@"空间分享不支持QQApiTextObject，请使用QQApiImageArrayForQZoneObject分享");
            break;
        }
        case EQQAPIQZONENOTSUPPORTIMAGE: {
            NSLog(@"空间分享不支持QQApiImageObject，请使用QQApiImageArrayForQZoneObject分享");
            break;
        }
        case EQQAPIVERSIONNEEDUPDATE: {
            NSLog(@"当前QQ版本太低，需要更新");
            break;
        }
        case ETIMAPIVERSIONNEEDUPDATE: {
            NSLog(@"当前TIM版本太低，需要更新");
            break;
        }
        case EQQAPITIMNOTINSTALLED: {
            NSLog(@"未安装TIM");
            break;
        }
        case EQQAPITIMNOTSUPPORTAPI: {
            NSLog(@"TIM API接口不支持");
            break;
        }
        case EQQAPISHAREDESTUNKNOWN: {
            NSLog(@"未指定分享到QQ或TIM");
        }
            break;
        case EQQAPISENDSUCESS: {
            NSLog(@"QQ发送成功");
            break;
        }
        default:
        {
            break;
        }
    }
}

- (void)tencentDidLogin {
    
}

- (void)tencentDidNotLogin:(BOOL)cancelled { 
    
}

- (void)tencentDidNotNetWork { 
    
}
#else
#endif
#pragma mark 生成卡片分享
/// 图片增加背景色
- (UIImage *)setBackgroundColorOfImage:(UIImage *)source color:(UIColor *)color{
    UIGraphicsBeginImageContextWithOptions(source.size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect rect = (CGRect){0, 0, source.size};
    
    CGContextSetFillColorWithColor(context, [[UIColor whiteColor] CGColor]);
    CGContextFillRect(context, rect);
    
    [source drawInRect:(CGRect){0,0,source.size}];
    UIImage *coloredImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return coloredImg;
}
/// 生成二维码
- (UIImage *)generateQRCodeImageWithString:(NSString *)string width:(CGFloat)width height:(CGFloat)height {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    
    // 创建并设置CIFilter对象
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setValue:data forKey:@"inputMessage"];
    [filter setValue:@"Q" forKey:@"inputCorrectionLevel"];
    
    // 获取生成的CIImage对象
    CIImage *qrcodeImage = filter.outputImage;
    
    // 缩放CIImage对象
    CGFloat scaleX = width / qrcodeImage.extent.size.width;
    CGFloat scaleY = height / qrcodeImage.extent.size.height;
    CIImage *transformedImage = [qrcodeImage imageByApplyingTransform:CGAffineTransformMakeScale(scaleX, scaleY)];
    
    // 将调整后的CIImage对象转换成UIImage对象，并显示在图像视图中
    UIImage *qrImage = [UIImage imageWithCIImage:transformedImage];
    return [self setBackgroundColorOfImage:qrImage color:[UIColor whiteColor]];
}
/// 图片设置圆角裁剪
- (UIImage *)roundedCornerImageWithImage:(UIImage *)image size:(CGSize)size cornerRadius:(CGFloat)cornerRadius {
    // Get your image somehow
    //    UIImage *image = [UIImage imageNamed:@"image.jpg"];
    
    // Begin a new image that will be the new image with the rounded corners
    // (here with the size of an UIImageView)
    UIGraphicsBeginImageContextWithOptions(size , NO, 2.0);
    CGRect bounds = CGRectMake(0, 0, size.width, size.height);
    // Add a clip before drawing anything, in the shape of an rounded rect
    [[UIBezierPath bezierPathWithRoundedRect:bounds
                                cornerRadius:cornerRadius] addClip];
    // Draw your image
    [image drawInRect:bounds];
    
    // Get the image, here setting the UIImageView image
    UIImage *myIMG  = UIGraphicsGetImageFromCurrentImageContext();
    
    // Lets forget about that we were drawing
    UIGraphicsEndImageContext();
    return myIMG;
}

- (UIImage *)shareImageWithTitle:(NSString *)title content:(NSString *)content url:(NSString *)url imageURL:(NSString *)imageURL price:(CGFloat)price size:(CGSize)canvasSize {
    UIGraphicsBeginImageContextWithOptions(canvasSize, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [[UIColor whiteColor] CGColor]);
    CGRect rect = (CGRect){0, 0, canvasSize};
    CGContextFillRect(context, rect);
    
    
    //    CGContextAddEllipseInRect(context, rect);
    //    CGContextClip(context);
    
    
    CGFloat totalHeight = 0;
    CGFloat margin = 0.072*canvasSize.width;
    NSString *string = @"";
    
    NSDictionary *textAttributes = nil;
    CGFloat qrCodeWidth = canvasSize.width*0.18;
    
    CGSize size = CGSizeMake(canvasSize.width-margin*2 - qrCodeWidth, 1000);
    CGSize textSize = CGSizeZero;
    
    // ----------------- Logo -----------------
    UIImage *logo = [self roundedCornerImageWithImage:[UIImage imageNamed:@"AppIcon-180x180"] size:CGSizeMake(60, 60) cornerRadius:8];
    CGFloat imgH = canvasSize.width - margin*2;
    [logo drawInRect:CGRectMake(margin, margin, margin*2, margin*2)];
    totalHeight += margin*2 + margin*2 - 10;
    
    // ----------------- 商品大图 -----------------
    //http://yanxuan.nosdn.127.net/1e112d632a40935aae55b14c529000a0.jpg
    UIImage *product = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:imageURL]]];
    imgH = canvasSize.width - margin*2;
    CGFloat imgW = product.size.width/product.size.height*imgH;
    [product drawInRect:CGRectMake(margin, totalHeight, imgW, imgH)];
    totalHeight += imgH + margin;
    
    // ------------- 标题 -----------------
    textAttributes = @{NSForegroundColorAttributeName:[UIColor blackColor],
                       NSFontAttributeName:[UIFont boldSystemFontOfSize:20*2]};
    textSize = [title boundingRectWithSize:size options:NSStringDrawingUsesLineFragmentOrigin  attributes:textAttributes context:nil].size;
    [title drawWithRect:CGRectMake(margin, totalHeight, size.width, size.height) options:NSStringDrawingUsesLineFragmentOrigin attributes:textAttributes context:nil];
    
    //----------------- 二维码 -----------------
    UIImage *qrcode = [self generateQRCodeImageWithString:@"长按图片，识别二维码" width:qrCodeWidth*2 height:qrCodeWidth*2];
    [qrcode drawInRect:CGRectMake(canvasSize.width -margin-qrCodeWidth, totalHeight, qrCodeWidth, qrCodeWidth)];
    //    totalHeight += imgH + margin;
    
    string = @"识别二维码\n查看商品详情";//@"长按图片，识别二维码\n查看商品详情";
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.alignment = NSTextAlignmentCenter;
    textAttributes = @{NSForegroundColorAttributeName:[UIColor lightGrayColor],
                       NSFontAttributeName:[UIFont systemFontOfSize:11*2],
                       NSParagraphStyleAttributeName:style};
    CGSize textSize1 = [string boundingRectWithSize:CGSizeMake(imgH, 1000) options:NSStringDrawingUsesLineFragmentOrigin attributes:textAttributes context:nil].size;
    [string drawWithRect:CGRectMake(canvasSize.width - margin - qrCodeWidth, totalHeight+ qrCodeWidth + 12*2, textSize1.width, textSize1.height) options:NSStringDrawingUsesLineFragmentOrigin attributes:textAttributes context:nil];
    
    
    totalHeight += textSize.height + 8*2;
    
    //    string = @"活力冻龄，轻松穿出高级感";
    // ----------------- 副标题 -----------------
    textAttributes = @{NSForegroundColorAttributeName:[UIColor lightGrayColor],
                       NSFontAttributeName:[UIFont systemFontOfSize:16*2]};
    textSize = [content boundingRectWithSize:size options:NSStringDrawingUsesLineFragmentOrigin  attributes:textAttributes context:nil].size;
    [title drawWithRect:CGRectMake(margin, totalHeight, textSize.width, textSize.height) options:NSStringDrawingUsesLineFragmentOrigin attributes:textAttributes context:nil];
    totalHeight += textSize.height + 11;
    
    string = [NSString stringWithFormat:@"￥%.0f",price];
    textAttributes = @{NSForegroundColorAttributeName:[UIColor colorWithRed:1.00 green:0.15 blue:0.32 alpha:1.00],
                       NSFontAttributeName:[UIFont boldSystemFontOfSize:40*2]};
    textSize = [string boundingRectWithSize:size options:NSStringDrawingUsesLineFragmentOrigin  attributes:textAttributes context:nil].size;
    [string drawWithRect:CGRectMake(margin+3, totalHeight, textSize.width, textSize.height) options:NSStringDrawingUsesLineFragmentOrigin attributes:textAttributes context:nil];
//    totalHeight += textSize.height + margin;
    
    
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return [self roundedCornerImageWithImage:image size:image.size cornerRadius:20];
}
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
//    BOOL success = false;
    if (!error) {
//        success = true;
        if ([PPShareManager sharedManager].shareHandler) {
            [PPShareManager sharedManager].shareHandler(@"已保存至相册");
        }
    } else {
        if (error.code == -3310) {
            if ([PPShareManager sharedManager].shareHandler) {
                [PPShareManager sharedManager].shareHandler(@"保存失败，请到系统设置检查此应用是否有访问系统相册的权限");
            }
            return;
        }
        if ([PPShareManager sharedManager].shareHandler) {
            [PPShareManager sharedManager].shareHandler(@"保存失败");
        }
    }
    
}
@end


#pragma mark - XDShareCollectionViewCell
@implementation XDShareCollectionViewCell
{
    UIImageView *_icon;
    UILabel *_bottomText;
}
- (void)xd_addSubviews {
    _icon = [UIImageView new];
    [self.contentView addSubview:_icon];
    
    _bottomText = [UILabel new];
    [self.contentView addSubview:_bottomText];
    _bottomText.textAlignment = NSTextAlignmentCenter;
    _bottomText.textColor = [UIColor darkGrayColor];
    _bottomText.font = [UIFont systemFontOfSize:12.f];
}

- (void)layoutSubviews {
    _icon.frame = CGRectMake((self.frame.size.width - PPIconW)/2, 10, PPIconW, PPIconW);
    _bottomText.frame = CGRectMake(0, self.frame.size.height - 25, self.frame.size.width, 25);
}

- (void)updateUIWithData:(NSDictionary *)model {
    _bottomText.text = model[@"text"];
    _icon.image =[UIImage imageNamed:model[@"icon"]];
}
@end
