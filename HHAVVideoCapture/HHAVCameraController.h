//
//  HHAVCameraController.h
//  HHAVVideoCapture
//
//  Created by 胡华翔 on 2018/3/29.
//  Copyright © 2018年 胡华翔. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

extern NSString *const HHAVThumbnailCreatedNotification;

/* 会话配置结果枚举 */
typedef NS_ENUM( NSInteger, HHAVVideoCaptureSetupResult ) {
    HHAVVideoCaptureSetupResultSuccess,
    HHAVVideoCaptureSetupResultCameraNotAuthorized,
    HHAVVideoCaptureSetupResultSessionConfigurationFailed
};

@protocol HHAVCameraControllerDelegate <NSObject>
@optional
- (void)sessionRuntimeError;
- (void)startSessionDidFinishedWithSetupResult:(HHAVVideoCaptureSetupResult)setupResult;
- (void)didFinishRecording:(NSError *)error;
- (void)didStartRecording;
- (void)updateRecordingTime:(NSString *)time;
- (void)torchModeActived:(BOOL)actived;
- (void)willCapturePhotoAnimation;
- (void)willToggleLivePhotoViewHidden:(BOOL)hidden;

- (void)isFlashScene:(BOOL)result;
@required
- (void)configrationSessionDidFinishedWithResult:(BOOL)result error:(NSError *)error;
@end

@interface HHAVCameraController : NSObject
/* 捕捉会话 */
@property (strong, nonatomic) AVCaptureSession *session;

/* 代理 */
@property (weak, nonatomic) id<HHAVCameraControllerDelegate> delegate;

/**
 配置会话
 */
- (void)setupSession;


/**
 启动会话
 */
- (void)startSession;


/**
 停止会话
 */
- (void)stopSession;


/**
 开始捕捉

 @param orientation 捕捉方向
 */
- (void)startCapture:(AVCaptureVideoOrientation)orientation;

/**
 开始拍照

 @param orientation 拍照方向
 @param flashMode 闪光灯模式
 */
- (void)captureStillImage:(AVCaptureVideoOrientation)orientation flashMode:(AVCaptureFlashMode)flashMode;

/**
 切换摄像头

 @return 切换成功或失败
 */
- (BOOL)switchCameras;


/**
 返回指定位置的摄像头

 @param position 位置
 @return 返回AVCaptureDevice对象
 */
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position;

/**
 当前激活的摄像头
 
 @return 当前激活的摄像头
 */
- (AVCaptureDevice *)activeCamera;


/**
 返回当前未激活的摄像头

 @return 当前未激活的摄像头
 */
- (AVCaptureDevice *)inactiveCamera;


/**
 判断是否可以切换摄像头

 @return YES为可切换,NO为不可切换
 */
- (BOOL)canSwitchCameras;


/**
 返回当前有多少个摄像头可用

 @return 摄像头数量
 */
- (NSUInteger)cameraCount;


/**
 返回摄像头是否有闪光灯

 @return YES为有,NO为没有
 */
- (BOOL)cameraHasFlash;

/**
 返回摄像头是否支持手电筒模式

 @return YES为支持,NO为不支持
 */
- (BOOL)cameraHasTorch;

/**
 返回当前手电筒模式

 @return 手电筒模式
 */
- (AVCaptureTorchMode)torchMode;

/**
 设置手电筒模式

 @param torchMode 手电筒模式
 */
- (void)setTorchMode:(AVCaptureTorchMode)torchMode;

/**
 是否支持点击对焦

 @return YES为支持,NO为不支持
 */
- (BOOL)cameraSupportsTapToFocus;

/**
 在指定的点上进行对焦

 @param point 指定的点(已由captureDevicePointOfInterestForPoint转后之后的点)
 */
- (void)focusAtPoint:(CGPoint)point;
/**
 是否支持点击曝光

 @return YES为支持,NO为不支持
 */
- (BOOL)cameraSupportsTapToExpose;

/**
 在指定的点上进行曝光
 
 @param point 指定的点(已由captureDevicePointOfInterestForPoint转后之后的点)
 */
- (void)exposeAtPoint:(CGPoint)point;

/**
 恢复对焦和曝光模式
 */
- (void)resetFocusAndExposureModes;

- (BOOL)isFocusModeContinuousAutoFocusSupported;

- (BOOL)isExposureModeContinuousAutoExposeSupported;

/**
 设置拍照会话模式

 @param error 设置错误信息
 */
- (void)setPhotoCaptureSession:(NSError * __autoreleasing *)error completionHandler:(void (^)(void))completionHandler;

/**
 设置录像会话模式
 
 @param error 设置错误信息
 */
- (void)setVideoRecordingSession:(NSError * __autoreleasing *)error completionHandler:(void (^)(void))completionHandler;

/**
 是否支持Live Photo

 @return YES:支持 NO：不支持
 */
- (BOOL)cameraSupportsLivePhoto;

/**
 实况拍摄是否开启

 @return YES:开启 NO：未开启
 */
- (BOOL)livePhotoEnabled;

/**
 设置实况拍摄状态

 @param enabled YES：设置为开启 NO：设置为关闭
 */
- (void)setLivePhotoEnabled:(BOOL)enabled;
@end
