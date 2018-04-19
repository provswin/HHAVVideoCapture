//
//  HHAVOverlayView.h
//  HHAVVideoCapture
//
//  Created by 胡华翔 on 2018/3/29.
//  Copyright © 2018年 胡华翔. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HHAVCaptureButton.h"
#import "HHAVFlashModeView.h"
#import "HHAVLiveButton.h"

typedef NS_ENUM(NSInteger, HHAVCaptureMode) {
    HHAVCaptureModeVideo  = 0,    // 视频模式
    HHAVCaptureModePhoto  = 1,    // 照片模式
};

@protocol HHAVOverlayViewDelegate <NSObject>
- (void)captureModeChanged:(HHAVCaptureMode)mode;
@end


@interface HHAVOverlayView : UIView
/* 当前所处的模式 （0：视频模式、1：照片模式）*/
@property (assign, nonatomic) HHAVCaptureMode mode;

/* 委托代理 */
@property (weak, nonatomic) id<HHAVOverlayViewDelegate> delegate;

/* 顶部视图 */
@property (weak, nonatomic) IBOutlet UIView *videoTopView;
@property (weak, nonatomic) IBOutlet UIView *photoTopView;

/* 底部视图 */
@property (weak, nonatomic) IBOutlet UIView *bottomView;

/* 捕捉按钮 */
@property (weak, nonatomic) IBOutlet HHAVCaptureButton *captureButton;

/* 缩略图按钮 */
@property (weak, nonatomic) IBOutlet UIButton *thumbnailButton;

/* 录制时间文本标签 */
@property (weak, nonatomic) IBOutlet UILabel *timerLabel;

/* 半透明黑色衬托视图 */
@property (weak, nonatomic) IBOutlet UIView *blackAssistView;

/* 切换摄像头按钮 */
@property (weak, nonatomic) IBOutlet UIButton *switchCameraButton;
@property (weak, nonatomic) IBOutlet UIButton *photoSwitchCameraButton;

/* 闪光灯切换按钮 */
@property (weak, nonatomic) IBOutlet UIButton *flashButton;

@property (weak, nonatomic) IBOutlet UIButton *photoFlashButton;

/* 闪光模式切换视图 */
@property (weak, nonatomic) IBOutlet HHAVFlashModeView *flashModeView;
@property (weak, nonatomic) IBOutlet HHAVFlashModeView *photoFlashModeView;

/* 自动对焦和自动曝光模式锁定、实况开启与关闭提示 */
@property(weak, nonatomic) IBOutlet UIButton *secondTipsButton;
/* 自动对焦和自动曝光模式锁定提示的宽度约束*/
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *autoFocusAndExposeTipsButtonWidthConstraint;

/* 手电筒模式是否处于激活状态 */
@property(weak, nonatomic) IBOutlet UIButton *firstTipsButton;
/* 手电筒模式按钮的宽度约束 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *torchActiveButtonWidthConstraint;

/* 滑动切换视频模式或拍照模式视图区域 */
@property (weak, nonatomic) IBOutlet UIView *swipeAreaView;

/* 照片模式选择按钮 */
@property (weak, nonatomic) IBOutlet UIButton *photoModeButton;

/* 视频模式选择按钮 */
@property (weak, nonatomic) IBOutlet UIButton *videoModeButton;

/* 模式切换模式容器视图 */
@property (weak, nonatomic) IBOutlet UIView *modeContainerView;

/* live Button */
@property (weak, nonatomic) IBOutlet HHAVLiveButton *liveButton;

/* HDR Button */
@property (weak, nonatomic) IBOutlet UIButton *hdrButton;

/**
 根据手势,对OverlayView进行界面及属性的设置

 @param recognizer 滑动手势
 */
- (void)handleSwipe:(UISwipeGestureRecognizer *)recognizer;
@end
