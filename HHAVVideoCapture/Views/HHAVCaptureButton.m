//
//  HHAVCaptureButton.m
//  HHAVVideoCapture
//
//  Created by 胡华翔 on 2018/3/29.
//  Copyright © 2018年 胡华翔. All rights reserved.
//

#import "HHAVCaptureButton.h"

#define kGapBetweenInLayerAndOutLayer  8;

@interface HHAVCaptureButton ()
/* 内部视图效果 */
@property (strong, nonatomic) CAShapeLayer *inLayer;

/* 内部视图圆形路径 */
@property (strong, nonatomic) UIBezierPath *circlePath;

/* 内部视图圆角矩形路径 */
@property (strong, nonatomic) UIBezierPath *roundRectPath;

/* 初始状态下内部视图宽度 */
@property (assign, nonatomic) float inLayerWidth;

/* 初始状态下内部视图高度 */
@property (assign, nonatomic) float inLayerHeight;
@end

@implementation HHAVCaptureButton
- (void)awakeFromNib {
    [super awakeFromNib];
    self.backgroundColor = [UIColor clearColor];
}

- (void)layoutSubviews {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        //create a path
        UIBezierPath *outBezierPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2) radius:self.frame.size.width / 2.2 startAngle:0 endAngle:M_PI*2 clockwise:YES];
        
        //draw the path using a CAShapeLayer
        CAShapeLayer *outLayer = [CAShapeLayer layer];
        outLayer.path = outBezierPath.CGPath;
        outLayer.fillColor = [UIColor clearColor].CGColor;
        outLayer.strokeColor = [UIColor whiteColor].CGColor;
        outLayer.lineWidth = 4.0f;
        [self.layer addSublayer:outLayer];
        
        //draw the path using a CAShapeLayer
        self.inLayerWidth = self.frame.size.width - outLayer.lineWidth * 2 - kGapBetweenInLayerAndOutLayer;
        self.inLayerHeight = self.frame.size.height - outLayer.lineWidth * 2 - kGapBetweenInLayerAndOutLayer;
        
        self.inLayer = [CAShapeLayer layer];
        self.inLayer.frame = CGRectMake(0, 0, self.inLayerWidth, self.inLayerHeight);
        self.inLayer.backgroundColor = [UIColor whiteColor].CGColor;
        self.inLayer.cornerRadius = self.inLayerWidth / 2;
        self.inLayer.position = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2);
        [self.layer addSublayer:self.inLayer];
    });
}

- (void)changeButtonWithButtonStatus:(HHAVCaptureButtonStatus)status previousStatus:(HHAVCaptureButtonStatus)previousStatus {
    switch (status) {
        case HHAVCaptureButtonStatusPhoto: {
            CABasicAnimation *colorAnimation = [CABasicAnimation animationWithKeyPath:@"backgroundColor"];
            colorAnimation.toValue = (id)[UIColor whiteColor].CGColor;
            
            colorAnimation.duration = 0.5f;
            colorAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
            colorAnimation.fillMode = kCAFillModeForwards;
            colorAnimation.removedOnCompletion = NO;
            [_inLayer addAnimation:colorAnimation forKey:nil];
        }
            break;
            
        case HHAVCaptureButtonStatusRecording: {
            CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"cornerRadius"];
            animation.toValue = [NSNumber numberWithFloat:5.f];
            
            CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
            scale.toValue = @0.6;
            
            CAAnimationGroup *group = [[CAAnimationGroup alloc] init];
            group.animations = @[animation, scale];
            group.duration = 0.5f;
            group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
            group.fillMode = kCAFillModeForwards;
            group.removedOnCompletion = NO;
            [_inLayer addAnimation:group forKey:nil];
        }
            break;
        case HHAVCaptureButtonStatusNotRecording: {
            if (previousStatus == HHAVCaptureButtonStatusPhoto) {
                CABasicAnimation *colorAnimation = [CABasicAnimation animationWithKeyPath:@"backgroundColor"];
                colorAnimation.toValue = (id)[UIColor redColor].CGColor;
                
                colorAnimation.duration = 0.5f;
                colorAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
                colorAnimation.fillMode = kCAFillModeForwards;
                colorAnimation.removedOnCompletion = NO;
                [_inLayer addAnimation:colorAnimation forKey:nil];
            } else {
                CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"cornerRadius"];
                animation.toValue = [NSNumber numberWithFloat:self.inLayerWidth / 2];
                
                CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
                scale.toValue = @1.0;
                
                CAAnimationGroup *group = [[CAAnimationGroup alloc] init];
                group.animations = @[animation, scale];
                group.duration = 0.5f;
                group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
                group.fillMode = kCAFillModeForwards;
                group.removedOnCompletion = NO;
                [_inLayer addAnimation:group forKey:nil];
            }
        }
            break;
    }
}
@end
