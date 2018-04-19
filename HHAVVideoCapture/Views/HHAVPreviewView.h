//
//  HHAVPreviewView.h
//  HHAVVideoCapture
//
//  Created by 胡华翔 on 2018/3/29.
//  Copyright © 2018年 胡华翔. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HHAVOverlayView.h"

@protocol HHAVPreviewViewDelegate <NSObject>
- (void)tappedToFocusAndExposeAtPoint:(CGPoint)point;
- (void)tappedToResetFocusAndExposure;
@end

@class AVCaptureSession;
@interface HHAVPreviewView : UIView
/* 委托代理 */
@property (weak, nonatomic) id<HHAVPreviewViewDelegate> delegate;

/* 关联的覆盖层 */
@property (strong, nonatomic) HHAVOverlayView *overlayView;

/* 捕捉会话 */
@property (strong, nonatomic) AVCaptureSession *session;

/* 是否开启点击对焦和曝光功能 */
@property (assign, nonatomic) BOOL tapToFocusAndExposeEnabled;

/* 是否开启长按自动对焦和曝光功能 */
@property (assign, nonatomic) BOOL longPressToFocusAndExposeAutoEnabled;

/* 是否滑动切换捕捉模式功能 */
@property (assign, nonatomic) BOOL swipeToSwitchModeEnabled;

/**
 设置AVCaptureVideoPreviewLayer的session
 
 @param session session会话
 */
- (void)setSession:(AVCaptureSession *)session;

/**
 返回AVCaptureVideoPreviewLayer的session
 
 @return session会话
 */
- (AVCaptureSession *)session;

/**
 传入屏幕坐标点，返回设备坐标点

 @param point 屏幕坐标点
 @return 设备坐标点
 */
- (CGPoint)captureDevicePointForPoint:(CGPoint)point;

- (void)setTapToFocusEnabled:(BOOL)enabled;

- (void)setLongPressToFocusAndExposeAutoEnable:(BOOL)enable;

- (void)setSwipeToSwitchModeEnabled:(BOOL)enabled;
@end
