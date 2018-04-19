//
//  HHAVOverlayView.m
//  HHAVVideoCapture
//
//  Created by 胡华翔 on 2018/3/29.
//  Copyright © 2018年 胡华翔. All rights reserved.
//

#import "HHAVOverlayView.h"

@interface HHAVOverlayView ()

@end

static void * HHAVOverlayViewContext = &HHAVOverlayViewContext;

@implementation HHAVOverlayView
- (void)dealloc {
    [self.secondTipsButton removeObserver:self forKeyPath:@"hidden"];

    [self.firstTipsButton removeObserver:self forKeyPath:@"hidden"];
}
- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        UIView *nib = [[NSBundle mainBundle] loadNibNamed:@"HHAVOverlayView" owner:self options:nil][0];
        [self addSubview:nib];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // 默认为照片模式
    _mode = HHAVCaptureModePhoto;
    _photoModeButton.selected = YES;
    _videoModeButton.selected = NO;
    
    self.autoFocusAndExposeTipsButtonWidthConstraint.constant = 0.f;
    
    self.torchActiveButtonWidthConstraint.constant = 0.f;

    [self.secondTipsButton addObserver:self forKeyPath:@"hidden" options:NSKeyValueObservingOptionNew context:HHAVOverlayViewContext];

    [self.firstTipsButton addObserver:self forKeyPath:@"hidden" options:NSKeyValueObservingOptionNew context:HHAVOverlayViewContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    if (context == &HHAVOverlayViewContext) {
        if (object == self.secondTipsButton) {
            if ([self.secondTipsButton isHidden]) {
                self.autoFocusAndExposeTipsButtonWidthConstraint.constant = 0.f;
            } else {
                self.autoFocusAndExposeTipsButtonWidthConstraint.constant = 152.f;
                if ([self.firstTipsButton isHidden]) {
                    CATransition *transition = [CATransition animation];
                    transition.type = kCATransitionPush;
                    transition.subtype = kCATransitionFromLeft;
                    [self.firstTipsButton.layer addAnimation:transition forKey:nil];
                }
            }
        } else if (object == self.firstTipsButton) {
            if ([self.firstTipsButton isHidden]) {
                self.torchActiveButtonWidthConstraint.constant = 0.f;
            } else {
                self.torchActiveButtonWidthConstraint.constant = 48.f;
                if (![self.secondTipsButton isHidden]) {
                    CATransition *transition = [CATransition animation];
                    transition.type = kCATransitionPush;
                    transition.subtype = kCATransitionFromRight;
                    [self.firstTipsButton.layer addAnimation:transition forKey:nil];
                }
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return [self.videoTopView pointInside:[self convertPoint:point toView:self.videoTopView] withEvent:event] ||
            [self.bottomView pointInside:[self convertPoint:point toView:self.bottomView] withEvent:event];
}

- (void)changeToVideoMode {
    if (_mode == HHAVCaptureModeVideo) {
        return;
    } else {
        [self setMode:HHAVCaptureModeVideo];
        CGRect videoFrame = _videoModeButton.frame;
        CGRect photoFrame = _photoModeButton.frame;
        [UIView animateWithDuration:0.2f animations:^{
            self.videoModeButton.frame = CGRectMake(videoFrame.origin.x + videoFrame.size.width, videoFrame.origin.y, videoFrame.size.width, videoFrame.size.height);
            self.photoModeButton.frame = CGRectMake(photoFrame.origin.x + photoFrame.size.width, photoFrame.origin.y, photoFrame.size.width, photoFrame.size.height);
            self.videoModeButton.selected = YES;
            self.photoModeButton.selected = NO;
        }];
        if ([self.delegate respondsToSelector:@selector(captureModeChanged:)]) {
            [self.delegate captureModeChanged:_mode];
        }
    }
}

- (void)changeToPhotoMode {
    if (_mode == HHAVCaptureModePhoto) {
        return;
    } else {
        [self setMode:HHAVCaptureModePhoto];
        CGRect videoFrame = _videoModeButton.frame;
        CGRect photoFrame = _photoModeButton.frame;
        [UIView animateWithDuration:0.2f animations:^{
            self.videoModeButton.frame = CGRectMake(videoFrame.origin.x - videoFrame.size.width, videoFrame.origin.y, videoFrame.size.width, videoFrame.size.height);
            self.photoModeButton.frame = CGRectMake(photoFrame.origin.x - photoFrame.size.width, photoFrame.origin.y, photoFrame.size.width, photoFrame.size.height);
            self.photoModeButton.selected = YES;
            self.videoModeButton.selected = NO;
        }];
        if ([self.delegate respondsToSelector:@selector(captureModeChanged:)]) {
            [self.delegate captureModeChanged:_mode];
        }
    }
}

- (void)handleSwipe:(UISwipeGestureRecognizer *)recognizer {
    if (UISwipeGestureRecognizerDirectionLeft == (recognizer.direction & UISwipeGestureRecognizerDirectionLeft)) {
        [self changeToPhotoMode];
    } else if (UISwipeGestureRecognizerDirectionRight == (recognizer.direction & UISwipeGestureRecognizerDirectionRight)) {
        [self changeToVideoMode];
    }
}

- (IBAction)changeToVideoModeAction:(id)sender {
    [self changeToVideoMode];
}
- (IBAction)changeToPhotoModeAction:(id)sender {
    [self changeToPhotoMode];
}

@end
