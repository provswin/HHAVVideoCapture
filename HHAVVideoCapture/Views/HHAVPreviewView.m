//
//  HHAVPreviewView.m
//  HHAVVideoCapture
//
//  Created by 胡华翔 on 2018/3/29.
//  Copyright © 2018年 胡华翔. All rights reserved.
//
#define BOX_BOUNDS CGRectMake(0.0f, 0.0f, 150.f, 150.0f)
#define BIG_BOX_BOUNDS CGRectMake(0.0f, 0.0f, 320.f, 320.f)

#import "HHAVPreviewView.h"
#import <AVFoundation/AVFoundation.h>
#import "JX_GCDTimerManager.h"

@interface HHAVPreviewView ()
/* 捕捉预览图层 */
@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *previewLayer;
/* 点击手势 */
@property (strong, nonatomic) UITapGestureRecognizer *tapGesture;

/* 长按手势 */
@property (strong, nonatomic) UILongPressGestureRecognizer *longPressGesture;

/* 对焦和曝光方框视图 */
@property (strong, nonatomic) UIView *focusAndExposeBox;

/* 锁定自动对焦和曝光方框视图 */
@property (strong, nonatomic) UIView *bigFocusAndExposeBox;

/* 移动手势 */
@property (strong, nonatomic) UISwipeGestureRecognizer *swipeLeftGesture;
@property (strong, nonatomic) UISwipeGestureRecognizer *swipeRightGesture;
@end

@implementation HHAVPreviewView

+ (Class)layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setupView];
    }
    return self;
}

- (void)setSession:(AVCaptureSession *)session {
    [(AVCaptureVideoPreviewLayer *)self.layer setSession:session];
}

- (AVCaptureSession *)session {
    return[(AVCaptureVideoPreviewLayer *)self.layer session];
}


- (void)setupView {
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    [self addGestureRecognizer:_tapGesture];

    _longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    _longPressGesture.minimumPressDuration = 1.0f;
    [self addGestureRecognizer:_longPressGesture];
    
    [_tapGesture requireGestureRecognizerToFail:_longPressGesture];
    
    _swipeLeftGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    _swipeLeftGesture.direction = UISwipeGestureRecognizerDirectionLeft;
    [self addGestureRecognizer:_swipeLeftGesture];
    
    _swipeRightGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    _swipeRightGesture.direction = UISwipeGestureRecognizerDirectionRight;
    [self addGestureRecognizer:_swipeRightGesture];
    
    _focusAndExposeBox = [self viewWithColor:[UIColor colorWithRed:0xff/255.f green:0xc5/255.f blue:0x02/255.f alpha:1] frame:BOX_BOUNDS];
    [self addSubview:_focusAndExposeBox];
    
    _bigFocusAndExposeBox = [self viewWithColor:[UIColor colorWithRed:0xff/255.f green:0xc5/255.f blue:0x02/255.f alpha:1] frame:BIG_BOX_BOUNDS];
    [self addSubview:_bigFocusAndExposeBox];
    
    _tapToFocusAndExposeEnabled = YES;
    _longPressToFocusAndExposeAutoEnabled = YES;
    _swipeToSwitchModeEnabled = YES;
}

- (void)handleSingleTap:(UIGestureRecognizer *)recognizer {
    if (_tapToFocusAndExposeEnabled) {
        CGPoint point = [recognizer locationInView:self];
        [self runBoxAnimationOnView:self.focusAndExposeBox point:point removeWhenFinish:YES timerName:@"focusAndExposeBox"];
        if ([self.delegate respondsToSelector:@selector(tappedToFocusAndExposeAtPoint:)]) {
            [self.delegate tappedToFocusAndExposeAtPoint:[self captureDevicePointForPoint:point]];
        }
    }
}

- (void)handleLongPress:(UIGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan) {
        if (recognizer.state == UIGestureRecognizerStateEnded) {
            [[JX_GCDTimerManager sharedInstance] cancelTimerWithName:@"bigFocusAndExposeBox"];
            [[JX_GCDTimerManager sharedInstance] scheduledDispatchTimerWithName:@"bigFocusAndExposeBox" timeInterval:0.5f queue:dispatch_get_main_queue() repeats:NO actionOption:AbandonPreviousAction action:^{
                self.bigFocusAndExposeBox.hidden = YES;
                self.bigFocusAndExposeBox.transform = CGAffineTransformIdentity;
            }];
        }
        return;
    }
    
    if (_longPressToFocusAndExposeAutoEnabled) {
        CGPoint point = [self center];
        [self runBoxAnimationOnView:self.bigFocusAndExposeBox point:point removeWhenFinish:NO timerName:nil];
        if ([self.delegate respondsToSelector:@selector(tappedToResetFocusAndExposure)]) {
            [self.delegate tappedToResetFocusAndExposure];
        }
    }
}

- (void)handleSwipe:(UISwipeGestureRecognizer *)recognizer {
    if (_swipeToSwitchModeEnabled) {
        [_overlayView handleSwipe:recognizer];
    }
}

- (void)runBoxAnimationOnView:(UIView *)view point:(CGPoint)point removeWhenFinish:(BOOL)removeWhenFinish timerName:(NSString *)timerName {
    view.center = point;
    view.hidden = NO;
    view.transform = CGAffineTransformIdentity;
    
    if (removeWhenFinish) {
        [[JX_GCDTimerManager sharedInstance] cancelTimerWithName:timerName];
    }
    
    [UIView animateWithDuration:0.15f
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         view.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0);
                     }
                     completion:^(BOOL complete) {
                         if (removeWhenFinish) {
                             [[JX_GCDTimerManager sharedInstance] scheduledDispatchTimerWithName:timerName timeInterval:0.5f queue:dispatch_get_main_queue() repeats:NO actionOption:AbandonPreviousAction action:^{
                                 view.hidden = YES;
                                 view.transform = CGAffineTransformIdentity;
                             }];
                         }
                     }];
}

- (void)setTapToFocusEnabled:(BOOL)enabled {
    _tapToFocusAndExposeEnabled = enabled;
    self.tapGesture.enabled = enabled;
}

- (void)setLongPressToFocusAndExposeAutoEnable:(BOOL)enable {
    _longPressToFocusAndExposeAutoEnabled = enable;
    self.longPressGesture.enabled = enable;
}

- (void)setSwipeToSwitchModeEnabled:(BOOL)enabled {
    _swipeToSwitchModeEnabled = enabled;
    self.swipeLeftGesture.enabled = enabled;
    self.swipeRightGesture.enabled = enabled;
}

- (UIView *)viewWithColor:(UIColor *)color frame:(CGRect)frame {
    UIView *view = [[UIView alloc] initWithFrame:frame];
    view.backgroundColor = [UIColor clearColor];
    view.layer.borderColor = color.CGColor;
    view.layer.borderWidth = 2.0f;
    view.hidden = YES;
    return view;
}

- (AVCaptureVideoPreviewLayer *)previewLayer {
    return (AVCaptureVideoPreviewLayer *)self.layer;
}

- (CGPoint)captureDevicePointForPoint:(CGPoint)point {
    AVCaptureVideoPreviewLayer *layer =
    (AVCaptureVideoPreviewLayer *)self.layer;
    return [layer captureDevicePointOfInterestForPoint:point];
}
@end
