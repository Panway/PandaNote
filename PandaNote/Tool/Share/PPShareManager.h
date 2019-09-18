//
//  XDShareView.h
//  DrawShareImage
//
//  Created by panway on 2018/7/4.
//  Copyright © 2018年 Panwei. All rights reserved.
//
// 自己封装的分享组件，可以只用微信分享、微博分享、QQ分享的0个或一个，也可以多个组合

#import <UIKit/UIKit.h>
#import "XDHorizontalItemView.h"

#if __has_include(<WXApi.h>)
#import <WXApi.h>
#define PP_USE_WECHAT_SHARE 1
#else
#define PP_USE_WECHAT_SHARE 0
#endif

#if __has_include(<Weibo_SDK/WeiboSDK.h>)
#import <Weibo_SDK/WeiboSDK.h>
#define PP_USE_WEIBO_SHARE 1
#else
#define PP_USE_WEIBO_SHARE 0
#endif


#if __has_include(<TencentOpenAPI/QQApiInterface.h>)
#import <TencentOpenAPI/QQApiInterface.h>
#import <TencentOpenAPI/TencentOAuth.h>
#define PP_USE_QQ_SHARE 1
#else
#define PP_USE_QQ_SHARE 0
#endif


//#import "WXApi.h"
//#import "WeiboSDK.h"
//#import <TencentOpenAPI/QQApiInterface.h>
//#import <TencentOpenAPI/TencentOAuth.h>
#import "XDCollectionViewCell.h"

//typedef HZCollectionViewCell XDCollectionViewCell;

typedef NS_ENUM (NSInteger,PPSharePlatform) {
    PPSharePlatformWeixinSession,
    PPSharePlatformWeixinTimeline,
    PPSharePlatformQQSession,
    PPSharePlatformQZone,
    PPSharePlatformWeibo,
    PPSharePlatformClipboard,
    PPSharePlatformImage
};

NS_ASSUME_NONNULL_BEGIN

@interface XDShareView : UIControl
/// dismiss的回调
@property (nonatomic, copy) void(^clickDismissView)(void);

/**
 *  显示到某个View上
 *
 *  @param superView 父视图
 *  @param alpha     背景黑色透明度
 *  @param animated  是否有弹出动画
 */
- (void)showInView:(UIView *)superView backgroundAlpha:(CGFloat)alpha animated:(BOOL)animated;
/**
 *  显示到某个View上
 *
 *  @param superView 父视图
 *  @param animated  是否有弹出动画
 */
- (void)showInView:(UIView *)superView animated:(BOOL)animated;
/// 显示到某个View上（默认有弹出动画,背景黑色透明度为0）
- (void)showInView:(UIView *)superView;
/// 显示到keyWindow上
- (void)show;
@property (nonatomic, copy) void(^shareHandler)(NSString * resultMsg);


//- (void)shareWithTitle:(NSString *)title content:(NSString *)content url:(NSString *)url platform:(PPSharePlatform)platform;
//- (void)dismissView;
@property (nonatomic) CGFloat white;
@property (nonatomic) CGFloat alphaa;
@end


#if PP_USE_WEIBO_SHARE
@interface PPShareManager : NSObject <WeiboSDKDelegate>
#else
@interface PPShareManager : NSObject

#endif
+ (nonnull instancetype)sharedManager;

@property(nonatomic,copy) NSString *title;
@property(nonatomic,copy) NSString *content;
@property(nonatomic,copy) NSString *url;
@property(nonatomic,strong) id image;
@property(nonatomic) BOOL shareOriginImage;///<分享大图，而不是链接

@property(nonatomic,copy) NSString *originalImageURL;///< 原始大图URL
#if PP_USE_WECHAT_SHARE
+ (void)initWeixinAppId:(NSString *)appId appKey:(NSString *)appKey;
- (void)weixinShareLinkWithUrl:(NSString *)url title:(NSString *)title description:(NSString *)description image:(id)image type:(NSInteger)type;
- (void)weixinShareImage:(UIImage *)image type:(NSInteger)type;
- (void)weixinShareEmoji:(NSData *)emoji type:(NSInteger)type;
#else
#endif



#if PP_USE_WEIBO_SHARE
+ (void)initWeiboAppId:(NSString *)appId appKey:(NSString *)appKey;
- (void)weiboShareLinkWithUrl:(NSString *)url title:(NSString *)title description:(NSString *)description image:(id)image;
#else
#endif




#if PP_USE_QQ_SHARE
+ (void)initQQAppId:(NSString *)appId appKey:(NSString *)appKey;
- (void)qqShareLinkWithUrl:(NSString *)url title:(NSString *)title description:(NSString *)description image:(id)image type:(NSInteger)type ;
#else
#endif

/// type: PPSharePlatformQQSession = 2, PPSharePlatformQZone = 3,
/// 分享结果block
@property (nonatomic, copy) void(^shareHandler)(NSString * resultMsg);
@property (nonatomic, copy) void(^loginHandler)(NSDictionary * resultDic);

- (void)shareWithTitle:(NSString *)title content:(NSString *)content url:(NSString *)url image:(id)image platform:(PPSharePlatform)platform completion:(void (^)(NSString * resultMsg))completion;

- (BOOL)handleOpenURL:(NSURL *)url;
@end



@interface XDShareCollectionViewCell : XDCollectionViewCell
@end
NS_ASSUME_NONNULL_END
