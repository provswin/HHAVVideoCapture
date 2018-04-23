//
//  HHAVCameraController.m
//  HHAVVideoCapture
//
//  Created by 胡华翔 on 2018/3/29.
//  Copyright © 2018年 胡华翔. All rights reserved.
//

#import "HHAVCameraController.h"
#import "HHAVPhotoCaptureDelegate.h"

NSString *const HHAVThumbnailCreatedNotification = @"THThumbnailCreated";

@interface HHAVCameraController () <AVCaptureFileOutputRecordingDelegate, AVCapturePhotoCaptureDelegate>
/* 捕捉队列 */
@property (strong, nonatomic) dispatch_queue_t videoQueue;

/* 视频输出 */
@property (strong, nonatomic) AVCaptureMovieFileOutput *movieFileOutput;

/* 照片输出 */
@property (strong, nonatomic) AVCapturePhotoOutput *photoOutput;

/* 会话配置结果 */
@property (assign, nonatomic) HHAVVideoCaptureSetupResult setupResult;

/* 后台任务标记*/
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;

/* 当前激活的视频输入 */
@property (weak, nonatomic) AVCaptureDeviceInput *activeVideoInput;

@property (nonatomic) NSMutableDictionary<NSNumber *, HHAVPhotoCaptureDelegate *> *inProgressPhotoCaptureDelegates;

@property (nonatomic) NSInteger inProgressLivePhotoCapturesCount;

/* 当前摄像头位置 */
@property(assign, nonatomic) AVCaptureDevicePosition cameraPosition;

/* 是否启用了Live Photo */
@property(assign, nonatomic) BOOL livePhotoModeEnable;
@end

static void *HHAVSessionRunningContext = &HHAVSessionRunningContext;

static void * HHAVCameraControllerTorchModeContext = &HHAVCameraControllerTorchModeContext;

static void *HHAVCameraControllerFlashSceneContext = &HHAVCameraControllerFlashSceneContext;

@implementation HHAVCameraController
- (void)dealloc {
    NSArray<AVCaptureDeviceType> *deviceTypes = @[AVCaptureDeviceTypeBuiltInWideAngleCamera];
    NSArray *devices = [[AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified] devices];
    for (AVCaptureDevice *device in devices) {
        [device removeObserver:self forKeyPath:@"torchActive"];
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_session removeObserver:self forKeyPath:@"running"];

    [_photoOutput removeObserver:self forKeyPath:@"isFlashScene"];
    [_photoOutput removeObserver:self forKeyPath:@"isStillImageStabilizationScene"];
}

- (void)setupSession {
    // 1.配置capture session
    _session = [[AVCaptureSession alloc] init];

    [_session addObserver:self forKeyPath:@"running" options:NSKeyValueObservingOptionNew context:HHAVSessionRunningContext];
    
    self.videoQueue = dispatch_queue_create("com.showsoft.videoQueue", NULL);
    
    self.setupResult = HHAVVideoCaptureSetupResultSuccess;
    
    /*
     判断是否具有视频权限;视频权限包括摄像头权限和麦克风权限，其中摄像头权限是必选，马克风权限是可选；
     如果麦克风权限访问被禁止，那么录制出来的视频就只有视频没有声音。
     */
    switch ( [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] )
    {
        case AVAuthorizationStatusAuthorized:
        {
            // 已经授权
            break;
        }
        case AVAuthorizationStatusNotDetermined:
        {
            /*
             也许用户还没有决定是否给与视频的访问权限。所以先挂起videoQueue线程，直到
             权限请求完成之后恢复。
             */
            dispatch_suspend( self.videoQueue );
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^( BOOL granted ) {
                if ( ! granted ) {
                    self.setupResult = HHAVVideoCaptureSetupResultCameraNotAuthorized;
                }
                dispatch_resume( self.videoQueue );
            }];
            break;
        }
        default:
        {
            // 用户不允许访问
            self.setupResult = HHAVVideoCaptureSetupResultCameraNotAuthorized;
            break;
        }
    }
    
    dispatch_async(self.videoQueue, ^{
        NSError *error;
        BOOL result = [self configrationSession:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(configrationSessionDidFinishedWithResult:error:)]) {
                [self.delegate configrationSessionDidFinishedWithResult:result error:error];
            }
        });
    });
}

- (void)setVideoRecordingSession:(NSError * __autoreleasing *)error completionHandler:(void (^)(void))completionHandler{
    dispatch_async(self.videoQueue, ^{
        [self configurationVideoRecordingSession:error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                completionHandler();
            }
        });
    });
}

- (BOOL)configurationVideoRecordingSession:(NSError **)error {
    [_session beginConfiguration];
    // 2.配置session的捕捉预设值
    if ([_session canSetSessionPreset:AVCaptureSessionPresetHigh]) {
        [_session setSessionPreset:AVCaptureSessionPresetHigh];
    }

    BOOL result = [self configVideoInput:error];

    _backgroundRecordingID = UIBackgroundTaskInvalid;
    
    // 视频
    if (_movieFileOutput) {
        if ([_session canAddOutput:_movieFileOutput]) {
            [_session addOutput:_movieFileOutput];
        }
    } else {
        _movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        // 最大可录制时长60分钟
        _movieFileOutput.maxRecordedDuration = CMTimeMake(60 * 60, 1);
        // 当磁盘空间小于50MB时,停止录制
        _movieFileOutput.minFreeDiskSpaceLimit = 50 * 1024 * 1024;
        if ([_session canAddOutput:_movieFileOutput]) {
            [_session addOutput:_movieFileOutput];
        }
    }
    
    [_session commitConfiguration];
    return result;
}

- (void)setPhotoCaptureSession:(NSError * __autoreleasing *)error completionHandler:(void (^)(void))completionHandler{
    dispatch_async(self.videoQueue, ^{
        [self configurationPhotoCaptureSession:error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                completionHandler();
            }
        });
    });
}

- (BOOL)configVideoInput:(NSError *__autoreleasing *)error {
    AVCaptureDevice *videoDevice;
    [_session beginConfiguration];

    if (self.cameraPosition == AVCaptureDevicePositionUnspecified) {
        self.cameraPosition = AVCaptureDevicePositionBack;
    }

    // 如果是前摄像头
    if (self.cameraPosition == AVCaptureDevicePositionFront) {
        videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
        // 如果前摄像头由于特殊原因无法获取则改为后摄像头
        if (!videoDevice) {
            self.cameraPosition = AVCaptureDevicePositionBack;

            // 首先获取是否有双后摄像后的设备
            videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInDuoCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];

            // 如果没有则获取单个后广角摄像头
            if (!videoDevice) {
                videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
            }
        }
    } else {
        // 如果不是前摄像头
        // 首先获取是否有双后摄像后的设备
        videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInDuoCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
        // 如果没有则获取单个后广角摄像头
        if (!videoDevice) {
            videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];

            // 如果后广角摄像头由于特殊原因无法获取则改为前摄像头
            if (!videoDevice) {
                self.cameraPosition = AVCaptureDevicePositionFront;
                videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
            }
        }
    }
    
    if (self.activeVideoInput) {
        [_session removeInput:self.activeVideoInput];
    }
    
    // 4.添加输入设备
    // 视频
    if (videoDevice) {
        AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:error];
        if (videoInput) {
            if ([_session canAddInput:videoInput]) {
                [_session addInput:videoInput];
                self.activeVideoInput = videoInput;
                self.inProgressPhotoCaptureDelegates = [NSMutableDictionary dictionary];
                self.inProgressLivePhotoCapturesCount = 0;
            }
        } else {
            self.setupResult = HHAVVideoCaptureSetupResultSessionConfigurationFailed;
            NSLog(@"[videoInput]:deviceInputWithDevice:error: return nil");
            [_session commitConfiguration];
            return NO;
        }
    } else {
        self.setupResult = HHAVVideoCaptureSetupResultSessionConfigurationFailed;
        NSLog(@"[videoInput]:defaultDeviceWithMediaType: return nil");
        [_session commitConfiguration];
        return NO;
    }
    [_session commitConfiguration];
    return YES;
}

- (BOOL)configurationPhotoCaptureSession:(NSError **)error {
    [_session beginConfiguration];
    // 2.配置session的捕捉预设值
    if ([_session canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
        [_session setSessionPreset:AVCaptureSessionPresetPhoto];
    }

    BOOL result = [self configVideoInput:error];

    [_session commitConfiguration];
    return result;
}

- (BOOL)configrationSession:(NSError **)error {
    if (self.setupResult != HHAVVideoCaptureSetupResultSuccess) {
        return NO;
    }
    
    // 1.开始配置会话
    [_session beginConfiguration];

    NSArray<AVCaptureDeviceType> *deviceTypes = @[AVCaptureDeviceTypeBuiltInWideAngleCamera];
    NSArray *devices = [[AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified] devices];
    
    // 3.为所有device增加KVO,用于监听torchActive状态
    for (AVCaptureDevice *device in devices) {
        [device addObserver:self forKeyPath:@"torchActive" options:NSKeyValueObservingOptionNew context:HHAVCameraControllerTorchModeContext];
    }
    
    if (![self configurationPhotoCaptureSession:error]) {
        return NO;
    }
    
    // 音频
    for (AVCaptureDevice *device in devices) {
        if ([device hasMediaType:AVMediaTypeAudio]) {
            AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
            if (audioDevice) {
                AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:error];
                if (audioInput) {
                    if ([_session canAddInput:audioInput]) {
                        [_session addInput:audioInput];
                    }
                } else {
                    self.setupResult = HHAVVideoCaptureSetupResultSessionConfigurationFailed;
                    NSLog(@"[audioInput]:deviceInputWithDevice:error: return nil");
                    [_session commitConfiguration];
                    return NO;
                }
            } else {
                self.setupResult = HHAVVideoCaptureSetupResultSessionConfigurationFailed;
                NSLog(@"[audioInput]:defaultDeviceWithMediaType: return nil");
                [_session commitConfiguration];
                return NO;
            }
            break;
        }
    }
    
    // 5.添加输出
    // connection relation:  Audio & Video -> AVCaptureMovieFileOutput
    // connection relation:  Video -> AVCaptureStillImageOutput
    
    // 照片
    _photoOutput = [[AVCapturePhotoOutput alloc] init];
    if ([_session canAddOutput:_photoOutput]) {
        [_session addOutput:_photoOutput];
        _photoOutput.highResolutionCaptureEnabled = YES;
        self.livePhotoEnabled = self.photoOutput.livePhotoCaptureSupported;
        _photoOutput.livePhotoCaptureEnabled = self.photoOutput.livePhotoCaptureSupported;
        if (@available(iOS 11.0, *)) {
            _photoOutput.depthDataDeliveryEnabled = self.photoOutput.depthDataDeliverySupported;
        } else {
            // Fallback on earlier versions
        }

        [_photoOutput addObserver:self forKeyPath:@"isFlashScene" options:NSKeyValueObservingOptionNew context:&HHAVCameraControllerFlashSceneContext];
        [_photoOutput addObserver:self forKeyPath:@"isStillImageStabilizationScene" options:NSKeyValueObservingOptionNew context:&HHAVCameraControllerFlashSceneContext];
    }
    
    NSNotificationCenter *nsnc = [NSNotificationCenter defaultCenter];
    [nsnc addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:nil];
    [_session commitConfiguration];
    return YES;
}

/**
 开始会话
 */
- (void)startSession {
    dispatch_async( self.videoQueue, ^{
        switch ( self.setupResult )
        {
            case HHAVVideoCaptureSetupResultSuccess:
            {
                // Only set up observers and start the session running if setup succeeded.
                [self.session startRunning];
                dispatch_async( dispatch_get_main_queue(), ^{
                    if ([self.delegate respondsToSelector:@selector(startSessionDidFinishedWithSetupResult:)]) {
                        [self.delegate startSessionDidFinishedWithSetupResult:self.setupResult];
                    }
                } );
                break;
            }
            case HHAVVideoCaptureSetupResultCameraNotAuthorized:
            {
                dispatch_async( dispatch_get_main_queue(), ^{
                    if ([self.delegate respondsToSelector:@selector(startSessionDidFinishedWithSetupResult:)]) {
                        [self.delegate startSessionDidFinishedWithSetupResult:self.setupResult];
                    }
                } );
                break;
            }
            case HHAVVideoCaptureSetupResultSessionConfigurationFailed:
            {
                dispatch_async( dispatch_get_main_queue(), ^{
                    if ([self.delegate respondsToSelector:@selector(startSessionDidFinishedWithSetupResult:)]) {
                        [self.delegate startSessionDidFinishedWithSetupResult:self.setupResult];
                    }
                } );
                break;
            }
        }
    } );
}

- (void)stopSession {
    dispatch_async(self.videoQueue, ^{
        [self.session stopRunning];
    });
}

- (void)startCapture:(AVCaptureVideoOrientation)orientation {
    dispatch_async( self.videoQueue, ^{
        if ( !self.movieFileOutput.isRecording ) {
            if ([[UIDevice currentDevice] isMultitaskingSupported]) {
                /*
                 设置后台任务。
                 */
                self.backgroundRecordingID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
            }
            
            // 开始录制前, 更新视频视频输出文件的方向
            AVCaptureConnection *movieFileOutputConnection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
            movieFileOutputConnection.videoOrientation = orientation;
            
            if ([movieFileOutputConnection isVideoStabilizationSupported]) {
                movieFileOutputConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
            }
            
            AVCaptureDevice *device = [self activeCamera];
            
            if (device.isSmoothAutoFocusSupported) {                            // 5
                NSError *error;
                if ([device lockForConfiguration:&error]) {
                    device.smoothAutoFocusEnabled = NO;
                    [device unlockForConfiguration];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([self.delegate respondsToSelector:@selector(configrationSessionDidFinishedWithResult:error:)]) {
                            [self.delegate configrationSessionDidFinishedWithResult:YES error:error];
                        }
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([self.delegate respondsToSelector:@selector(configrationSessionDidFinishedWithResult:error:)]) {
                            [self.delegate configrationSessionDidFinishedWithResult:NO error:error];
                        }
                    });
                }
            }
            
            // 录制到临时目录
            NSString *outputFileName = [NSUUID UUID].UUIDString;
            NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[outputFileName stringByAppendingPathExtension:@"mov"]];
            
            [self.movieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath] recordingDelegate:self];
        }
        else {
            [self.movieFileOutput stopRecording];
        }
    } );
}

#pragma mark - Image Capture Methods
- (void)captureStillImage:(AVCaptureVideoOrientation)orientation flashMode:(AVCaptureFlashMode)flashMode {
    dispatch_async( self.videoQueue, ^{
        AVCaptureConnection *photoOutputConnection = [self.photoOutput connectionWithMediaType:AVMediaTypeVideo];
        photoOutputConnection.videoOrientation = orientation;
        
        
        // Capture HEIF photo when supported, with flash set to auto and high resolution photo enabled.
        AVCapturePhotoSettings *photoSettings;
        if (@available(iOS 11.0, *)) {
            if ([self.photoOutput.availablePhotoCodecTypes containsObject:AVVideoCodecTypeHEVC]) {
                photoSettings = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey: AVVideoCodecTypeHEVC}];
            } else {
                photoSettings = [AVCapturePhotoSettings photoSettings];
            }
        } else {
            // Fallback on earlier versions
            photoSettings = [AVCapturePhotoSettings photoSettings];
        }
        //        _photoSettings.autoStillImageStabilizationEnabled = YES;
        photoSettings.highResolutionPhotoEnabled = YES;
        
        self->_photoOutput.photoSettingsForSceneMonitoring = photoSettings;
        
        if ( self.activeVideoInput.device.isFlashAvailable ) {
            photoSettings.flashMode = flashMode;
        }

        if (photoSettings.availablePreviewPhotoPixelFormatTypes.count > 0) {
            photoSettings.previewPhotoFormat = @{(NSString *) kCVPixelBufferPixelFormatTypeKey: photoSettings.availablePreviewPhotoPixelFormatTypes.firstObject};
        }

        if (self.livePhotoModeEnable && self.photoOutput.livePhotoCaptureSupported) { // Live Photo capture is not supported in movie mode.
            NSString *livePhotoMovieFileName = [NSUUID UUID].UUIDString;
            NSString *livePhotoMovieFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[livePhotoMovieFileName stringByAppendingPathExtension:@"mov"]];
            photoSettings.livePhotoMovieFileURL = [NSURL fileURLWithPath:livePhotoMovieFilePath];
        }
        
        if (@available(iOS 11.0, *)) {
            if ( self.photoOutput.depthDataDeliveryEnabled && self.photoOutput.isDepthDataDeliverySupported ) {
                photoSettings.depthDataDeliveryEnabled = YES;
            } else {
                photoSettings.depthDataDeliveryEnabled = NO;
            }
        }
        // Use a separate object for the photo capture delegate to isolate each capture life cycle.
        HHAVPhotoCaptureDelegate *photoCaptureDelegate = [[HHAVPhotoCaptureDelegate alloc] initWithRequestedPhotoSettings:photoSettings willCapturePhotoAnimation:^{
            dispatch_async( dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(willCapturePhotoAnimation)]) {
                    [self.delegate willCapturePhotoAnimation];
                }
            } );
        }                                                                                         livePhotoCaptureHandler:^(BOOL capturing) {
            /*
             Because Live Photo captures can overlap, we need to keep track of the
             number of in progress Live Photo captures to ensure that the
             Live Photo label stays visible during these captures.
             */
            dispatch_async( self.videoQueue, ^{
                if ( capturing ) {
                    self.inProgressLivePhotoCapturesCount++;
                }
                else {
                    self.inProgressLivePhotoCapturesCount--;
                }
                
                NSInteger inProgressLivePhotoCapturesCount = self.inProgressLivePhotoCapturesCount;
                dispatch_async( dispatch_get_main_queue(), ^{
                    if ( inProgressLivePhotoCapturesCount > 0 ) {
                        if ([self.delegate respondsToSelector:@selector(willToggleLivePhotoViewHidden:)]) {
                            [self.delegate willToggleLivePhotoViewHidden:NO];
                        }
                    }
                    else if ( inProgressLivePhotoCapturesCount == 0 ) {
                        if ([self.delegate respondsToSelector:@selector(willToggleLivePhotoViewHidden:)]) {
                            [self.delegate willToggleLivePhotoViewHidden:YES];
                        }
                    }
                    else {
                        NSLog( @"Error: In progress live photo capture count is less than 0" );
                    }
                } );
            } );
        }                                                                                               completionHandler:^(HHAVPhotoCaptureDelegate *photoCaptureDelegate, NSData *imageData) {
            if (imageData) {
                [self postThumbnailNotifification:[UIImage imageWithData:imageData]];
            }
            
            // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
            dispatch_async( self.videoQueue, ^{
                self.inProgressPhotoCaptureDelegates[@(photoCaptureDelegate.requestedPhotoSettings.uniqueID)] = nil;
            } );
        }];
        
        /*
         The Photo Output keeps a weak reference to the photo capture delegate so
         we store it in an array to maintain a strong reference to this object
         until the capture is completed.
         */
        self.inProgressPhotoCaptureDelegates[@(photoCaptureDelegate.requestedPhotoSettings.uniqueID)] = photoCaptureDelegate;
        [self.photoOutput capturePhotoWithSettings:photoSettings delegate:photoCaptureDelegate];
    } );
}

#pragma mark - Device Configuration

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position { // 1
    NSArray<AVCaptureDeviceType> *deviceTypes = @[AVCaptureDeviceTypeBuiltInWideAngleCamera];
    NSArray *devices = [[AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified] devices];
    for (AVCaptureDevice *device in devices) {                              // 2
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

/**
 当前激活的摄像头
 
 @return 当前激活的摄像头
 */
- (AVCaptureDevice *)activeCamera {                                         // 3
    return self.activeVideoInput.device;
}

- (AVCaptureDevice *)inactiveCamera {                                       // 4
    AVCaptureDevice *device = nil;
    if (self.cameraCount > 1) {
        if ([self activeCamera].position == AVCaptureDevicePositionBack) {  // 5
            device = [self cameraWithPosition:AVCaptureDevicePositionFront];
            self.cameraPosition = AVCaptureDevicePositionFront;
        } else {
            device = [self cameraWithPosition:AVCaptureDevicePositionBack];
            self.cameraPosition = AVCaptureDevicePositionBack;
        }
    }

    return device;
}

- (BOOL)canSwitchCameras {                                                  // 6
    return self.cameraCount > 1;
}

- (NSUInteger)cameraCount {                                                 // 7
    NSArray<AVCaptureDeviceType> *deviceTypes = @[AVCaptureDeviceTypeBuiltInWideAngleCamera];
    NSArray *devices = [[AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified] devices];
    return [devices count];
}

- (BOOL)switchCameras {
    
    if (![self canSwitchCameras]) {                                         // 1
        return NO;
    }
    
    NSError *error;
    AVCaptureDevice *videoDevice = [self inactiveCamera];                   // 2
    
    AVCaptureDeviceInput *videoInput =
    [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    
    if (videoInput) {
        [self.session beginConfiguration];                           // 3
        
        [self.session removeInput:self.activeVideoInput];            // 4
        
        if ([self.session canAddInput:videoInput]) {                 // 5
            [self.session addInput:videoInput];
            self.activeVideoInput = videoInput;
        } else {
            [self.session addInput:self.activeVideoInput];
        }
        
        [self.session commitConfiguration];                          // 6
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(configrationSessionDidFinishedWithResult:error:)]) {
                [self.delegate configrationSessionDidFinishedWithResult:YES error:error];
            }
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(configrationSessionDidFinishedWithResult:error:)]) {
                [self.delegate configrationSessionDidFinishedWithResult:NO error:error];
            }
        });
        return NO;
    }
    return YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    if (context == &HHAVCameraControllerTorchModeContext) {                     // 5
        AVCaptureDevice *device = (AVCaptureDevice *)object;
        if (device == self.activeCamera) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(torchModeActived:)]) {
                    [self.delegate torchModeActived:device.torchActive];
                }
            });
        }
    } else if (context == &HHAVSessionRunningContext) {

    } else if (context == &HHAVCameraControllerFlashSceneContext) {
        if (_photoOutput) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(isFlashScene:)]) {
                    [self.delegate isFlashScene:self->_photoOutput.isFlashScene];
                }
            });
        }
    } else {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

#pragma mark - Live Photo

- (BOOL)cameraSupportsLivePhoto {
    if (self.photoOutput) {
        return self.photoOutput.livePhotoCaptureSupported;
    }
    return NO;
}

- (BOOL)livePhotoEnabled {
    if (self.photoOutput) {
        return self.livePhotoModeEnable;
    }
    return NO;
}

- (void)setLivePhotoEnabled:(BOOL)enabled {
    dispatch_async(self.videoQueue, ^{
        if (self.photoOutput) {
            if ([self cameraSupportsLivePhoto]) {
                self.livePhotoModeEnable = enabled;
            } else {
                self.livePhotoModeEnable = NO;
            }
        }
    });
}

#pragma mark - Flash and Torch Modes
- (BOOL)cameraHasFlash {
    return [[self activeCamera] hasFlash];
}

- (BOOL)cameraHasTorch {
    return [[self activeCamera] hasTorch];
}

- (AVCaptureTorchMode)torchMode {
    return [[self activeCamera] torchMode];
}

- (void)setTorchMode:(AVCaptureTorchMode)torchMode {
    
    AVCaptureDevice *device = [self activeCamera];
    
    if (device.torchMode != torchMode &&
        [device isTorchModeSupported:torchMode]) {
        
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.torchMode = torchMode;
            [device unlockForConfiguration];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(configrationSessionDidFinishedWithResult:error:)]) {
                    [self.delegate configrationSessionDidFinishedWithResult:YES error:error];
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(configrationSessionDidFinishedWithResult:error:)]) {
                    [self.delegate configrationSessionDidFinishedWithResult:NO error:error];
                }
            });
        }
    }
}

#pragma mark - Focus Methods

- (BOOL)cameraSupportsTapToFocus {                                          // 1
    return [[self activeCamera] isFocusPointOfInterestSupported];
}

- (BOOL)isFocusModeContinuousAutoFocusSupported {
    return [[self activeCamera] isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus];
}

- (void)focusAtPoint:(CGPoint)point {                                       // 2
    
    AVCaptureDevice *device = [self activeCamera];
    
    if (device.isFocusPointOfInterestSupported &&                           // 3
        [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        
        NSError *error;
        if ([device lockForConfiguration:&error]) {                         // 4
            device.focusPointOfInterest = point;
            device.focusMode = AVCaptureFocusModeAutoFocus;
            [device unlockForConfiguration];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(configrationSessionDidFinishedWithResult:error:)]) {
                    [self.delegate configrationSessionDidFinishedWithResult:YES error:error];
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(configrationSessionDidFinishedWithResult:error:)]) {
                    [self.delegate configrationSessionDidFinishedWithResult:NO error:error];
                }
            });
        }
    }
}

#pragma mark - Exposure Methods

- (BOOL)cameraSupportsTapToExpose {                                         // 1
    return [[self activeCamera] isExposurePointOfInterestSupported];
}

- (BOOL)isExposureModeContinuousAutoExposeSupported {
    return [[self activeCamera] isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure];
}

// Define KVO context pointer for observing 'adjustingExposure" device property.
static const NSString *THCameraAdjustingExposureContext;

- (void)exposeAtPoint:(CGPoint)point {
    
    AVCaptureDevice *device = [self activeCamera];
    
    AVCaptureExposureMode exposureMode =
    AVCaptureExposureModeAutoExpose;
    
    if (device.isExposurePointOfInterestSupported &&                        // 2
        [device isExposureModeSupported:exposureMode]) {
        
        NSError *error;
        if ([device lockForConfiguration:&error]) {                         // 3
            
            device.exposurePointOfInterest = point;
            device.exposureMode = exposureMode;
            
            [device unlockForConfiguration];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(configrationSessionDidFinishedWithResult:error:)]) {
                    [self.delegate configrationSessionDidFinishedWithResult:YES error:error];
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(configrationSessionDidFinishedWithResult:error:)]) {
                    [self.delegate configrationSessionDidFinishedWithResult:NO error:error];
                }
            });
        }
    }
}

- (void)resetFocusAndExposureModes {
    
    AVCaptureDevice *device = [self activeCamera];
    
    AVCaptureExposureMode exposureMode =
    AVCaptureExposureModeContinuousAutoExposure;
    
    AVCaptureFocusMode focusMode = AVCaptureFocusModeContinuousAutoFocus;
    
    BOOL canResetFocus = [device isFocusPointOfInterestSupported] &&        // 1
    [device isFocusModeSupported:focusMode];
    
    BOOL canResetExposure = [device isExposurePointOfInterestSupported] &&  // 2
    [device isExposureModeSupported:exposureMode];
    
    CGPoint centerPoint = CGPointMake(0.5f, 0.5f);                          // 3
    
    NSError *error;
    if ([device lockForConfiguration:&error]) {
        
        if (canResetFocus) {                                                // 4
            device.focusMode = focusMode;
            device.focusPointOfInterest = centerPoint;
        }
        
        if (canResetExposure) {                                             // 5
            device.exposureMode = exposureMode;
            device.exposurePointOfInterest = centerPoint;
        }
        
        [device unlockForConfiguration];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(configrationSessionDidFinishedWithResult:error:)]) {
                [self.delegate configrationSessionDidFinishedWithResult:YES error:error];
            }
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(configrationSessionDidFinishedWithResult:error:)]) {
                [self.delegate configrationSessionDidFinishedWithResult:NO error:error];
            }
        });
    }
}

#pragma mark - delegate
- (void)sessionRuntimeError:(NSNotification *)notification {
    NSLog(@"sessionRuntimeError");
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(sessionRuntimeError)]) {
            [self.delegate sessionRuntimeError];
        }
    });
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    // 更新录制时间
    [self updateRecordingTime];
    
    // Enable the Record button to let the user stop the recording.
    dispatch_async( dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(didStartRecording)]) {
            [self.delegate didStartRecording];
        }
    });
}

- (void)captureOutput:(nonnull AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(nonnull NSURL *)outputFileURL fromConnections:(nonnull NSArray<AVCaptureConnection *> *)connections error:(nullable NSError *)error {
    /*
     注意：currentBackgroundRecordingID用于接受录制关联的后台任务。
     当开始一个新录制时，应该使用一个新的后台任务ID

     因为我们对于每一个录制都使用唯一的文件路径进行存储，因此当开始一个新的录制时，不会覆盖当前正在存储的文件
     */
    UIBackgroundTaskIdentifier currentBackgroundRecordingID = self.backgroundRecordingID;
    self.backgroundRecordingID = UIBackgroundTaskInvalid;
    
    dispatch_block_t cleanup = ^{
        if ( [[NSFileManager defaultManager] fileExistsAtPath:outputFileURL.path] ) {
            [[NSFileManager defaultManager] removeItemAtPath:outputFileURL.path error:NULL];
        }
        
        if ( currentBackgroundRecordingID != UIBackgroundTaskInvalid ) {
            [[UIApplication sharedApplication] endBackgroundTask:currentBackgroundRecordingID];
        }
    };
    
    BOOL success = YES;
    
    if ( error ) {
        NSLog( @"Movie file finishing error: %@", error );
        success = [error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] boolValue];
    }
    if ( success ) {
        // 检查是否有照片库权限
        [PHPhotoLibrary requestAuthorization:^( PHAuthorizationStatus status ) {
            if ( status == PHAuthorizationStatusAuthorized ) {
                // 将视频文件存储到图片库中，并清理
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                    // iOS 9以后支持移动文件到图片库中,但是由于我们需要截图图片做缩略图
                    // 所以这里不设置移动图片, 否则会导致截图失败
                    options.shouldMoveFile = NO;

                    PHAssetCreationRequest *creationRequest = [PHAssetCreationRequest creationRequestForAsset];
                    [creationRequest addResourceWithType:PHAssetResourceTypeVideo fileURL:outputFileURL options:options];
                } completionHandler:^( BOOL success, NSError *error ) {
                    if ( ! success ) {
                        NSLog( @"Could not save movie to photo library: %@", error );
                    }
                    [self generateThumbnailForVideoAtUrl:outputFileURL completionHandler:^{
                        cleanup();
                    }];
                }];
            }
            else {
                cleanup();
            }
        }];
    }
    else {
        cleanup();
    }
    
    dispatch_async( dispatch_get_main_queue(), ^{
        // 完成录制后,通知主线程更新UI
        if ([self.delegate respondsToSelector:@selector(didFinishRecording:)]) {
            [self.delegate didFinishRecording:error];
        }
    });
}

- (void)updateRecordingTime {
    if ([self.movieFileOutput isRecording]) {
        NSUInteger time = CMTimeGetSeconds([self.movieFileOutput recordedDuration]);
        NSInteger hours = (time / 3600);
        NSInteger minutes = (time / 60) % 60;
        NSInteger seconds = (time % 60);
        
        dispatch_async( dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(updateRecordingTime:)]) {
                [self.delegate updateRecordingTime:[NSString stringWithFormat:@"%02li:%02li:%02li", (long) hours, (long) minutes, (long) seconds]];
            }
        });
        
        [self performSelector:@selector(updateRecordingTime) withObject:nil afterDelay:.1f];
    }
}

- (void)generateThumbnailForVideoAtUrl:(NSURL *)url completionHandler:(void (^)(void))completionHandler {
    dispatch_async(self.videoQueue, ^{
        AVAsset *asset = [AVAsset assetWithURL:url];
        
        AVAssetImageGenerator *imageGenerator =                             // 5
        [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        imageGenerator.maximumSize = CGSizeMake(600, 0.f);
        imageGenerator.appliesPreferredTrackTransform = YES;
        
        CGImageRef imageRef = [imageGenerator copyCGImageAtTime:kCMTimeZero // 6
                                                     actualTime:NULL
                                                          error:nil];
        UIImage *image = [UIImage imageWithCGImage:imageRef];
        CGImageRelease(imageRef);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self postThumbnailNotifification:image];
            dispatch_async(self.videoQueue, ^{
                if (completionHandler) {
                    completionHandler();
                }
            });
        });
    });
}

#pragma mark - thumbnail
- (UIImage *)getThumbnailImage:(NSURL *)videoPath {
    if (videoPath) {
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoPath options:nil];
        AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        // 设定缩略图的方向，如果不设定，可能会在视频旋转90/180/270°时，获取到的缩略图是被旋转过的，而不是正向的。
        gen.appliesPreferredTrackTransform = YES;
        // 设置图片的最大size(分辨率)
        gen.maximumSize = CGSizeMake(300, 169);
        CMTime time = CMTimeMakeWithSeconds(5.0, 600); // 取第5秒，一秒钟600帧
        NSError *error = nil;
        CMTime actualTime;
        CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];
        if (error) {
            UIImage *placeHoldImg = [UIImage imageNamed:@"<默认图片名>"];
            return placeHoldImg;
        }
        UIImage *thumb = [[UIImage alloc] initWithCGImage:image];
        CGImageRelease(image);
        return thumb;
    } else {
        UIImage *placeHoldImg = [UIImage imageNamed:@"<默认图片名>"];
        return placeHoldImg;
    }
}

- (void)postThumbnailNotifification:(UIImage *)image {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:HHAVThumbnailCreatedNotification object:image];
    });
}
@end
