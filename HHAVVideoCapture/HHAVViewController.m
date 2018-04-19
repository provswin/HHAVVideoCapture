//
//  ViewController.m
//  HHAVVideoCapture
//
//  Created by 胡华翔 on 2018/3/29.
//  Copyright © 2018年 胡华翔. All rights reserved.
//

#import "HHAVViewController.h"
#import "HHAVCameraController.h"
#import "HHAVCameraView.h"

@interface HHAVViewController () <HHAVCameraControllerDelegate, HHAVPreviewViewDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, PHPhotoLibraryChangeObserver, HHAVOverlayViewDelegate>
/* 捕捉控制器 */
@property (strong, nonatomic) HHAVCameraController *cameraController;
/* 捕捉视图 */
@property (weak, nonatomic) IBOutlet HHAVCameraView *cameraView;

/* 相册资源获取结果 */
@property (strong, nonatomic) PHFetchResult *fetchResult;

/* 捕捉照片时的闪光灯模式 */
@property (assign, nonatomic) HHAVFlashMode photoFlashMode;
@end

@implementation HHAVViewController

- (void)dealloc {
    [self removeObserver];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _cameraView.overlayView.captureButton.enabled = NO;
    
    // 1.初始化摄像头控制类
    _cameraController = [[HHAVCameraController alloc] init];
    _cameraController.delegate = self;
    
    // 2.配置会话
    [_cameraController setupSession];
    
    // 3.关联AVCaptureVideoPreviewLayer和session的关系
    [_cameraView.previewView setSession:_cameraController.session];
    _cameraView.previewView.delegate = self;
    
    // 4.设置overlayView的代理
    _cameraView.overlayView.delegate = self;

    // 5.设置按钮的响应事件
    [self buttonActionSet];
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if ( status == PHAuthorizationStatusAuthorized ) {
            PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
            fetchOptions.sortDescriptors = @[
                                             [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO],
                                             ];
            self.fetchResult = [PHAsset fetchAssetsWithOptions:fetchOptions];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.fetchResult count] > 0) {
                    PHAsset *asset = [self.fetchResult objectAtIndex:0];
                    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
                    options.version = PHImageRequestOptionsVersionUnadjusted;
                    options.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
                    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(600.0, 600.f) contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                        [self.cameraView.overlayView.thumbnailButton setImage:[result imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
                        self.cameraView.overlayView.thumbnailButton.imageView.layer.cornerRadius = 5.f;
                        self.cameraView.overlayView.thumbnailButton.imageView.clipsToBounds = YES;
                        self.cameraView.overlayView.thumbnailButton.imageView.contentMode = UIViewContentModeScaleAspectFill;
                    }];
                }
            });
        } else {
            NSLog(@"Photo Library permission error!");
        }
    }];
    
    [self addObserver];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)addObserver {
    NSNotificationCenter *nsnc = [NSNotificationCenter defaultCenter];
    [nsnc addObserver:self selector:@selector(updateThumbnail:) name:HHAVThumbnailCreatedNotification object:nil];
    
    [nsnc addObserver:self selector:@selector(subjectAreaDidChange:) name: AVCaptureDeviceSubjectAreaDidChangeNotification object:nil];
    
    [nsnc addObserver:self selector:@selector(sessionWasInterrupted:) name: AVCaptureSessionWasInterruptedNotification object:nil];
    
    [nsnc addObserver:self selector:@selector(sessionInterruptedEnded:) name: AVCaptureSessionInterruptionEndedNotification object:nil];
    
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
}

- (void)removeObserver {
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 启动会话
    [_cameraController startSession];
    
    // 保持屏幕常亮
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.cameraView.overlayView.mode == HHAVCaptureModePhoto) {
            self.cameraView.previewView.frame = CGRectMake(0, self.cameraView.overlayView.photoTopView.frame.size.height, self.cameraView.frame.size.width, self.cameraView.frame.size.width * 4 / 3);
        }
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // 停止会话
    [_cameraController stopSession];
    
    // 保持屏幕常亮
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void)buttonActionSet {
    // 1.设置点击捕捉按钮响应事件
    [_cameraView.overlayView.captureButton addTarget:self action:@selector(captureAction:) forControlEvents:UIControlEventTouchUpInside];

    // 2.设置切换摄像头按钮
    [_cameraView.overlayView.switchCameraButton addTarget:self action:@selector(switchCamera:) forControlEvents:UIControlEventTouchUpInside];
    [_cameraView.overlayView.photoSwitchCameraButton addTarget:self action:@selector(switchCamera:) forControlEvents:UIControlEventTouchUpInside];

    // 3.设置选择闪光灯模式按钮
    [_cameraView.overlayView.flashButton addTarget:self action:@selector(flashModeSelectAction:) forControlEvents:UIControlEventTouchUpInside];
    [_cameraView.overlayView.photoFlashButton addTarget:self action:@selector(flashModeSelectAction:) forControlEvents:UIControlEventTouchUpInside];

    // 4.设置闪光灯模式设置按钮
    [_cameraView.overlayView.flashModeView.modeAutoButton addTarget:self action:@selector(torchModeChange:) forControlEvents:UIControlEventTouchUpInside];
    [_cameraView.overlayView.flashModeView.modeOnButton addTarget:self action:@selector(torchModeChange:) forControlEvents:UIControlEventTouchUpInside];
    [_cameraView.overlayView.flashModeView.modeOffButton addTarget:self action:@selector(torchModeChange:) forControlEvents:UIControlEventTouchUpInside];
    [_cameraView.overlayView.photoFlashModeView.modeAutoButton addTarget:self action:@selector(torchModeChange:) forControlEvents:UIControlEventTouchUpInside];
    [_cameraView.overlayView.photoFlashModeView.modeOnButton addTarget:self action:@selector(torchModeChange:) forControlEvents:UIControlEventTouchUpInside];
    [_cameraView.overlayView.photoFlashModeView.modeOffButton addTarget:self action:@selector(torchModeChange:) forControlEvents:UIControlEventTouchUpInside];

    // 5.缩略图按钮
    [_cameraView.overlayView.thumbnailButton addTarget:self action:@selector(thumbnailAction:) forControlEvents:UIControlEventTouchUpInside];

    // 6.live button按钮
    [_cameraView.overlayView.liveButton addTarget:self action:@selector(liveButtonAction:) forControlEvents:UIControlEventTouchUpInside];

    // 7. hdr按钮
    [_cameraView.overlayView.hdrButton addTarget:self action:@selector(hdrButtonAction:) forControlEvents:UIControlEventTouchUpInside];
}

/**
 捕捉点击

 @param sender 按钮
 */
- (void)captureAction:(id)sender {
    if ([_cameraController.session isRunning]) {
        /*
         在进入session的videoQueue之前，在主线程接受视频预览图层的方向。
         避免在进入videoQueue线程，再访问UI层相关信息
         */
        
        AVCaptureVideoOrientation videoPreviewLayerOrientation = ((AVCaptureVideoPreviewLayer *)_cameraView.previewView.layer).connection.videoOrientation;
        
        if (_cameraView.overlayView.mode == HHAVCaptureModeVideo) {
            [_cameraController startCapture:videoPreviewLayerOrientation];
        } else {
            AVCaptureFlashMode mode = AVCaptureFlashModeAuto;
            switch (_photoFlashMode) {
                case HHAVFlashModeOn:
                    mode = AVCaptureFlashModeOn;
                    break;
                case HHAVFlashModeOff:
                    mode = AVCaptureFlashModeOff;
                    break;
                case HHAVFlashModeAuto:
                    mode = AVCaptureFlashModeAuto;
                    break;
            }
            [_cameraController captureStillImage:videoPreviewLayerOrientation flashMode:mode];
        }
    }
}

- (void)switchCamera:(id)sender {
    if ([_cameraController switchCameras]) {
        [self tappedToFocusAndExposeAtPoint:[(AVCaptureVideoPreviewLayer *)_cameraView.previewView.layer captureDevicePointOfInterestForPoint:[_cameraView.previewView center]]];
        
        if ([[_cameraController activeCamera] isTorchActive]) {
            _cameraView.overlayView.firstTipsButton.hidden = NO;
        } else {
            _cameraView.overlayView.firstTipsButton.hidden = YES;
        }
    }
}

/**
 是否展开闪光灯模式选择视图

 @param sender 闪光灯模式选择Button
 */
- (void)flashModeSelectAction:(id)sender {
    if (_cameraView.overlayView.mode == HHAVCaptureModePhoto) {
        if ([_cameraView.overlayView.photoFlashModeView isHidden]) {
            _cameraView.overlayView.photoFlashModeView.hidden = NO;
            _cameraView.overlayView.photoSwitchCameraButton.hidden = YES;
            _cameraView.overlayView.hdrButton.hidden = YES;
            _cameraView.overlayView.liveButton.hidden = YES;
            [_cameraView.overlayView.photoFlashModeView initViewWithMode:_photoFlashMode];
        } else {
            _cameraView.overlayView.photoFlashModeView.hidden = YES;
            _cameraView.overlayView.photoSwitchCameraButton.hidden = NO;
            _cameraView.overlayView.hdrButton.hidden = NO;
            _cameraView.overlayView.liveButton.hidden = NO;
        }
    } else {
        if ([_cameraView.overlayView.flashModeView isHidden]) {
            _cameraView.overlayView.flashModeView.hidden = NO;
            _cameraView.overlayView.timerLabel.hidden = YES;
            _cameraView.overlayView.switchCameraButton.hidden = YES;
            HHAVFlashMode mode = (HHAVFlashMode)[_cameraController torchMode];
            [_cameraView.overlayView.flashModeView initViewWithMode:mode];
        } else {
            _cameraView.overlayView.flashModeView.hidden = YES;
            _cameraView.overlayView.timerLabel.hidden = NO;
            _cameraView.overlayView.switchCameraButton.hidden = NO;
        }
    }
}

- (void)torchModeChange:(id)sender {
    UIButton *button = (UIButton *)sender;
    if (_cameraView.overlayView.mode == HHAVCaptureModeVideo) {
        switch (button.tag) {
            case 0:
                [_cameraController setTorchMode:AVCaptureTorchModeOff];
                [_cameraView.overlayView.flashButton setImage:[UIImage imageNamed:@"camera_flash_off.png"] forState:UIControlStateNormal];
                break;
            case 1:
                [_cameraController setTorchMode:AVCaptureTorchModeOn];
                [_cameraView.overlayView.flashButton setImage:[UIImage imageNamed:@"camera_flash_on.png"] forState:UIControlStateNormal];
                break;
            case 2:
                [_cameraController setTorchMode:AVCaptureTorchModeAuto];
                [_cameraView.overlayView.flashButton setImage:[UIImage imageNamed:@"camera_flash_auto.png"] forState:UIControlStateNormal];
                break;
        }
#ifdef HHAV_TORCH_MODE_PREFERENCE
        AVCaptureTorchMode mode = [_cameraController torchMode];
        [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:@"torchMode"];
#endif
        _cameraView.overlayView.flashModeView.hidden = YES;
        _cameraView.overlayView.timerLabel.hidden = NO;
        _cameraView.overlayView.switchCameraButton.hidden = NO;
    } else {
        switch (button.tag) {
            case 0:
                _photoFlashMode = HHAVFlashModeOff;
                _cameraView.overlayView.firstTipsButton.hidden = YES;
                [_cameraView.overlayView.photoFlashButton setImage:[UIImage imageNamed:@"camera_flash_off.png"] forState:UIControlStateNormal];
                break;
            case 1:
                _photoFlashMode = HHAVFlashModeOn;
                _cameraView.overlayView.firstTipsButton.hidden = NO;
                [_cameraView.overlayView.photoFlashButton setImage:[UIImage imageNamed:@"camera_flash_on.png"] forState:UIControlStateNormal];
                break;
            case 2:
                _photoFlashMode = HHAVFlashModeAuto;
                _cameraView.overlayView.firstTipsButton.hidden = !_cameraController.activeCamera.torchActive;
                [_cameraView.overlayView.photoFlashButton setImage:[UIImage imageNamed:@"camera_flash_auto.png"] forState:UIControlStateNormal];
                break;
        }
#ifdef HHAV_FLASH_MODE_PREFERENCE
        [[NSUserDefaults standardUserDefaults] setInteger:_photoFlashMode forKey:@"flashMode"];
#endif
        _cameraView.overlayView.photoFlashModeView.hidden = YES;
        _cameraView.overlayView.liveButton.hidden = NO;
        _cameraView.overlayView.photoSwitchCameraButton.hidden = NO;
        _cameraView.overlayView.hdrButton.hidden = NO;
    }
}

- (void)thumbnailAction:(id)sender {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    picker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:picker.sourceType];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)liveButtonAction:(id)sender {
    if ([_cameraController livePhotoEnabled]) {
        // 当前未开启时设置为关闭状态
        [_cameraView.overlayView.liveButton setSelected:NO];
        [_cameraController setLivePhotoEnabled:NO];
        _cameraView.overlayView.secondTipsButton.hidden = YES;
    } else {
        [_cameraView.overlayView.liveButton setSelected:YES];
        [_cameraController setLivePhotoEnabled:YES];
        [_cameraView.overlayView.secondTipsButton setTitle:@"  实况  " forState:UIControlStateNormal];
        _cameraView.overlayView.secondTipsButton.hidden = NO;
    }
}

- (void)hdrButtonAction:(id)sender {
    UIButton *button = (UIButton *) sender;
    if (self.cameraView.overlayView.photoFlashModeView.hidden == NO) {
        CGRect newFrame = CGRectMake(button.frame.size.width, 0, button.frame.size.width, button.frame.size.height);
        [UIView animateWithDuration:0.3f animations:^{
            button.frame = newFrame;
            self.cameraView.overlayView.photoFlashModeView.hidden = YES;
        }                completion:^(BOOL finished) {
            self.cameraView.overlayView.photoFlashButton.hidden = NO;
            self.cameraView.overlayView.liveButton.hidden = NO;
            self.cameraView.overlayView.photoSwitchCameraButton.hidden = NO;
        }];
    } else {
        CGRect newFrame = CGRectMake(0, 0, button.frame.size.width, button.frame.size.height);
        [UIView animateWithDuration:0.3f animations:^{
            button.frame = newFrame;
            self.cameraView.overlayView.photoFlashButton.hidden = YES;
            self.cameraView.overlayView.liveButton.hidden = YES;
            self.cameraView.overlayView.photoSwitchCameraButton.hidden = YES;
        }                completion:^(BOOL finished) {
            [UIView animateWithDuration:0.2f animations:^{
                self.cameraView.overlayView.photoFlashModeView.hidden = NO;
            }];
        }];
    }
}

- (void)flashButtonUpdateState {
    if ([_cameraController.activeCamera hasTorch]) {
        _cameraView.overlayView.flashButton.hidden = NO;
        
#ifdef HHAV_TORCH_MODE_PREFERENCE
        AVCaptureTorchMode mode = [[NSUserDefaults standardUserDefaults] integerForKey:@"torchMode"];
        if (_cameraView.overlayView.mode == HHAVCaptureModeVideo) {
            [_cameraController setTorchMode:mode];
        }
#else
        AVCaptureTorchMode mode = [_cameraController torchMode];
#endif
        switch (mode) {
            case AVCaptureTorchModeAuto:
                [_cameraView.overlayView.flashModeView initViewWithMode:HHAVFlashModeAuto];
                [_cameraView.overlayView.flashButton setImage:[UIImage imageNamed:@"camera_flash_auto.png"] forState:UIControlStateNormal];
                break;
                
            case AVCaptureTorchModeOn:
                [_cameraView.overlayView.flashModeView initViewWithMode:HHAVFlashModeOn];
                [_cameraView.overlayView.flashButton setImage:[UIImage imageNamed:@"camera_flash_on.png"] forState:UIControlStateNormal];
                break;
                
            case AVCaptureTorchModeOff:
                [_cameraView.overlayView.flashModeView initViewWithMode:HHAVFlashModeOff];
                [_cameraView.overlayView.flashButton setImage:[UIImage imageNamed:@"camera_flash_off.png"] forState:UIControlStateNormal];
                break;
        }
    } else {
        _cameraView.overlayView.flashButton.hidden = YES;
    }
    
    if ([_cameraController.activeCamera hasFlash]) {
#ifdef HHAV_FLASH_MODE_PREFERENCE
        _photoFlashMode = [[NSUserDefaults standardUserDefaults] integerForKey:@"flashMode"];
#else
        _photoFlashMode = HHAVFlashModeAuto;
#endif
        switch (_photoFlashMode) {
            case HHAVFlashModeAuto:
                [_cameraView.overlayView.photoFlashModeView initViewWithMode:HHAVFlashModeAuto];
                [_cameraView.overlayView.photoFlashButton setImage:[UIImage imageNamed:@"camera_flash_auto.png"] forState:UIControlStateNormal];
                break;
                
            case HHAVFlashModeOn:
                [_cameraView.overlayView.photoFlashModeView initViewWithMode:HHAVFlashModeOn];
                [_cameraView.overlayView.photoFlashButton setImage:[UIImage imageNamed:@"camera_flash_on.png"] forState:UIControlStateNormal];
                break;
                
            case HHAVFlashModeOff:
                [_cameraView.overlayView.photoFlashModeView initViewWithMode:HHAVFlashModeOff];
                [_cameraView.overlayView.photoFlashButton setImage:[UIImage imageNamed:@"camera_flash_off.png"] forState:UIControlStateNormal];
                break;
        }
    } else {
        _photoFlashMode = HHAVFlashModeAuto;
        _cameraView.overlayView.photoFlashButton.hidden = YES;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/**
 收到通知后更新缩略图

 @param notification HHAVThumbnailCreatedNotification通知
 */
- (void)updateThumbnail:(NSNotification *)notification {
    UIImage *image = notification.object;
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.frame = CGRectMake(0, 0, _cameraView.overlayView.thumbnailButton.frame.size.width, _cameraView.overlayView.thumbnailButton.frame.size.height);
    imageView.layer.cornerRadius = 5.f;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    [_cameraView.overlayView.thumbnailButton addSubview:imageView];
    imageView.layer.affineTransform = CGAffineTransformMakeScale(0.f, 0.f);

    [UIView animateWithDuration:0.5f animations:^{
        imageView.layer.affineTransform = CGAffineTransformMakeScale(1.f, 1.f);
        imageView.layer.cornerRadius = 5.f;
    } completion:^(BOOL finished) {
        [self.cameraView.overlayView.thumbnailButton setImage:[image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
        self.cameraView.overlayView.thumbnailButton.imageView.layer.cornerRadius = 5.f;
        self.cameraView.overlayView.thumbnailButton.imageView.clipsToBounds = YES;
        self.cameraView.overlayView.thumbnailButton.imageView.contentMode = UIViewContentModeScaleAspectFill;
        [imageView removeFromSuperview];
    }];
}

/**
 收到通知后进入自动曝光模式和自动对焦

 @param notification AVCaptureDeviceSubjectAreaDidChangeNotification通知
 */
- (void)subjectAreaDidChange:(NSNotification *)notification {
//    [_cameraController resetFocusAndExposureModes];
    NSLog(@"subjectAreaDidChange");
}

- (void)sessionWasInterrupted:(NSNotification *)notification {
    NSLog(@"sessionWasInterrupted");
}

- (void)sessionInterruptedEnded:(NSNotification *)notification {
    NSLog(@"sessionInterruptedEnded");
}

#pragma mark - HHAVCameraControllerDelegate
/**
 配置捕捉会话结果

 @param result 成功或失败
 @param error 失败信息
 */
- (void)configrationSessionDidFinishedWithResult:(BOOL)result error:(NSError *)error {
    if (_cameraView.overlayView.mode == HHAVCaptureModePhoto) {
        if ([_cameraController cameraSupportsLivePhoto]) {
            _cameraView.overlayView.liveButton.hidden = NO;
        } else {
            _cameraView.overlayView.liveButton.hidden = YES;
        }
    }

    if (result) {
        // 初始化闪光灯默认模式
        [self flashButtonUpdateState];
        
        // 使捕捉按钮可用
        _cameraView.overlayView.captureButton.enabled = YES;
    } else {
        if (error) {
            NSLog(@"setupSession error = %@", [error localizedDescription]);
        }
    }
}


/**
 启动捕捉会话结果

 @param setupResult 结果
 */
- (void)startSessionDidFinishedWithSetupResult:(HHAVVideoCaptureSetupResult)setupResult {
    switch (setupResult) {
        case HHAVVideoCaptureSetupResultSuccess:
            break;
        case HHAVVideoCaptureSetupResultCameraNotAuthorized: {
            NSString *message = NSLocalizedString( @"AVMetadataRecordPlay doesn't have permission to use the camera, please change privacy settings", @"Alert message when the user has denied access to the camera" );
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVMetadataRecordPlay" message:message preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
            [alertController addAction:cancelAction];
            // Provide quick access to Settings.
            UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"Settings", @"Alert button to open Settings" ) style:UIAlertActionStyleDefault handler:^( UIAlertAction *action ) {
                if (@available(iOS 10.0, *)) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
                } else {
                    // Fallback on earlier versions
                }
            }];
            [alertController addAction:settingsAction];
            [self presentViewController:alertController animated:YES completion:nil];
        }
            break;
        case HHAVVideoCaptureSetupResultSessionConfigurationFailed: {
            dispatch_async( dispatch_get_main_queue(), ^{
                NSString *message = NSLocalizedString( @"Unable to capture media", @"Alert message when something goes wrong during capture session configuration" );
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVMetadataRecordPlay" message:message preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                [alertController addAction:cancelAction];
                [self presentViewController:alertController animated:YES completion:nil];
            } );
        }
            break;
    }
}


/**
 已经完成录制

 @param error 是否录制有错误
 */
- (void)didFinishRecording:(NSError *)error {
    _cameraView.overlayView.captureButton.enabled = YES;
    _cameraView.overlayView.timerLabel.text = @"00:00:00";
    // 更新按钮未开始录制状态
    [_cameraView.overlayView.captureButton changeButtonWithButtonStatus:HHAVCaptureButtonStatusNotRecording previousStatus:HHAVCaptureButtonStatusRecording];
    
    // 显示缩略图和半透明黑色背景视图
    _cameraView.overlayView.thumbnailButton.hidden = NO;
    _cameraView.overlayView.blackAssistView.hidden = NO;
    _cameraView.overlayView.switchCameraButton.hidden = NO;
    _cameraView.overlayView.flashButton.hidden = NO;
    _cameraView.overlayView.modeContainerView.hidden = NO;
    
    [_cameraView.previewView setSwipeToSwitchModeEnabled:YES];
}


/**
 开始录制
 */
- (void)didStartRecording {
    _cameraView.overlayView.captureButton.enabled = YES;
    _cameraView.overlayView.timerLabel.text = @"00:00:00";
    // 更新按钮录制中状态
    [_cameraView.overlayView.captureButton changeButtonWithButtonStatus:HHAVCaptureButtonStatusRecording previousStatus:HHAVCaptureButtonStatusNotRecording];
    
    // 隐藏缩略图和半透明黑色背景视图
    _cameraView.overlayView.flashModeView.hidden = YES;
    _cameraView.overlayView.timerLabel.hidden = NO;
    _cameraView.overlayView.switchCameraButton.hidden = NO;
    _cameraView.overlayView.thumbnailButton.hidden = YES;
    _cameraView.overlayView.blackAssistView.hidden = YES;
    _cameraView.overlayView.switchCameraButton.hidden = YES;
    _cameraView.overlayView.flashButton.hidden = YES;
    _cameraView.overlayView.modeContainerView.hidden = YES;
    [_cameraView.previewView setSwipeToSwitchModeEnabled:NO];
}

- (void)torchModeActived:(BOOL)actived {
    if (_cameraView.overlayView.mode == HHAVCaptureModeVideo) {
#ifdef HHAV_TORCH_MODE_PREFERENCE
        AVCaptureTorchMode mode = (AVCaptureTorchMode) [[NSUserDefaults standardUserDefaults] integerForKey:@"torchMode"];
#else
        AVCaptureTorchMode mode = [_cameraController torchMode];
#endif
        if (mode == AVCaptureTorchModeAuto) {
            _cameraView.overlayView.firstTipsButton.hidden = !actived;
        }
    }
}

- (void)isFlashScene:(BOOL)result {
    // TODO :目前未知isFlashScene为什么总是NO,待查明
    if (_cameraView.overlayView.mode == HHAVCaptureModePhoto) {
        if (self.photoFlashMode == HHAVFlashModeAuto) {
            _cameraView.overlayView.firstTipsButton.hidden = !result;
        }
    }
}

/**
 录制时间有更新

 @param time 格式化后的字符串
 */
- (void)updateRecordingTime:(NSString *)time {
    if (time) {
        _cameraView.overlayView.timerLabel.text = time;
    }
}

- (void)willCapturePhotoAnimation {
    _cameraView.previewView.layer.opacity = 0.0;
    [UIView animateWithDuration:0.25 animations:^{
        self.cameraView.previewView.layer.opacity = 1.0;
    }];
}

#pragma mark -- HHAVPreviewViewDelegate
- (void)tappedToFocusAndExposeAtPoint:(CGPoint)point {
    _cameraView.overlayView.secondTipsButton.hidden = YES;

    [_cameraController focusAtPoint:point];
    [_cameraController exposeAtPoint:point];
}

- (void)tappedToResetFocusAndExposure {
    BOOL focusModeCotinuousAutoFocusSupported = [_cameraController isFocusModeContinuousAutoFocusSupported];
    BOOL exposureModeCotinuousAutoExposeSupported = [_cameraController isExposureModeContinuousAutoExposeSupported];
    if (focusModeCotinuousAutoFocusSupported && exposureModeCotinuousAutoExposeSupported) {
        [_cameraView.overlayView.secondTipsButton setTitle:@"  自动曝光/自动对焦锁定  " forState:UIControlStateNormal];
        _cameraView.overlayView.secondTipsButton.hidden = NO;
    } else if (focusModeCotinuousAutoFocusSupported) {
        [_cameraView.overlayView.secondTipsButton setTitle:@"  自动对焦锁定  " forState:UIControlStateNormal];
        _cameraView.overlayView.secondTipsButton.hidden = NO;
    } else if (exposureModeCotinuousAutoExposeSupported) {
        [_cameraView.overlayView.secondTipsButton setTitle:@"  自动曝光锁定  " forState:UIControlStateNormal];
        _cameraView.overlayView.secondTipsButton.hidden = NO;
    } else {
        _cameraView.overlayView.secondTipsButton.hidden = YES;
    }
    
    [_cameraController resetFocusAndExposureModes];
}

#pragma mark -- UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -- PHPhotoLibraryChangeObserver
- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    //1. 获取更改的详情
    PHFetchResultChangeDetails *detail = [changeInstance changeDetailsForFetchResult:_fetchResult];
    //2.获取更改之后的结果集
    PHFetchResult<PHAsset *> *afterResult = [detail fetchResultAfterChanges];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([afterResult count] > 0) {
            // 3.获取结果集最新的一张图片用于显示在缩略图上
            PHAsset *asset = [afterResult objectAtIndex:0];
            PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
            options.version = PHImageRequestOptionsVersionUnadjusted;
            options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
            options.resizeMode = PHImageRequestOptionsResizeModeNone;
            options.synchronous = YES;
            [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(600.0, 600.f) contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                [self.cameraView.overlayView.thumbnailButton setImage:[result imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
                self.cameraView.overlayView.thumbnailButton.imageView.layer.cornerRadius = 5.f;
                self.cameraView.overlayView.thumbnailButton.imageView.clipsToBounds = YES;
                self.cameraView.overlayView.thumbnailButton.imageView.contentMode = UIViewContentModeScaleAspectFill;
            }];
        }
    });
}

#pragma mark -- HHAVOverlayViewDelegate
- (void)captureModeChanged:(HHAVCaptureMode)mode {
    NSError *error;
    
    __weak typeof(self) weakSelf = self;
    if (mode == HHAVCaptureModePhoto) {
        [_cameraController setPhotoCaptureSession:&error completionHandler:^{
            __strong HHAVViewController *strongSelf = weakSelf;
            [strongSelf.cameraView.overlayView.captureButton changeButtonWithButtonStatus:HHAVCaptureButtonStatusPhoto previousStatus:HHAVCaptureButtonStatusNotRecording];
            strongSelf.cameraView.overlayView.videoTopView.hidden = YES;
            strongSelf.cameraView.overlayView.photoTopView.hidden = NO;
            strongSelf.cameraView.previewView.frame = CGRectMake(0, strongSelf.cameraView.overlayView.photoTopView.frame.size.height, strongSelf.cameraView.frame.size.width, strongSelf.cameraView.frame.size.width * 4 / 3);
            // 初始化闪光灯默认模式
            [strongSelf flashButtonUpdateState];
        }];
        
    } else {
        [_cameraController setVideoRecordingSession:&error completionHandler:^{
            __strong HHAVViewController *strongSelf = weakSelf;
            [strongSelf.cameraView.overlayView.captureButton changeButtonWithButtonStatus:HHAVCaptureButtonStatusNotRecording previousStatus:HHAVCaptureButtonStatusPhoto];
            strongSelf.cameraView.overlayView.videoTopView.hidden = NO;
            strongSelf.cameraView.overlayView.photoTopView.hidden = YES;
            strongSelf.cameraView.previewView.frame = CGRectMake(0, 0, strongSelf.cameraView.frame.size.width, strongSelf.cameraView.frame.size.height);
            // 初始化闪光灯默认模式
            [strongSelf flashButtonUpdateState];
        }];
    }
}
@end
