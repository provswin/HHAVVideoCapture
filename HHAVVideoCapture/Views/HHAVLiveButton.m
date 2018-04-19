//
//  HHAVLiveButton.m
//  HHAVVideoCapture
//
//  Created by 胡华翔 on 2018/4/8.
//  Copyright © 2018年 胡华翔. All rights reserved.
//

#import "HHAVLiveButton.h"

@interface HHAVLiveButton ()
/* 当前按钮绘制颜色 */
@property(strong, nonatomic) UIColor *strokeColor;

/* 最小的圆环 */
@property(strong, nonatomic) CAShapeLayer *smallCircle;

/* 中等圆环 */
@property(strong, nonatomic) CAShapeLayer *middleCircle;

/* 最大的圆环 */
@property(strong, nonatomic) CAShapeLayer *largeCircle;
@end

@implementation HHAVLiveButton
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.tintColor = [UIColor clearColor];
        [self setupView];
    }
    return self;
}

- (void)setupView {
    CGFloat smallCircleRadius = 2.8f;
    CGFloat middleCircleRadius = 8.f;
    CGFloat largeCircleRadius = 12.f;

    _strokeColor = [UIColor colorWithRed:0xff / 255.f green:0xff / 255.f blue:0xff / 255.f alpha:1];

    _smallCircle = [CAShapeLayer layer];
    _smallCircle.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2) radius:smallCircleRadius startAngle:0 endAngle:M_PI * 2 clockwise:YES].CGPath;
    
    // Configure the apperence of the circle
    _smallCircle.fillColor = [UIColor clearColor].CGColor;
    _smallCircle.strokeColor = _strokeColor.CGColor;
    _smallCircle.lineWidth = 1.8f;
    [self.layer addSublayer:_smallCircle];

    _middleCircle = [CAShapeLayer layer];
    _middleCircle.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2) radius:middleCircleRadius startAngle:0 endAngle:M_PI * 2 clockwise:YES].CGPath;
    
    // Configure the apperence of the circle
    _middleCircle.fillColor = [UIColor clearColor].CGColor;
    _middleCircle.strokeColor = _strokeColor.CGColor;
    _middleCircle.lineWidth = 1.f;
    [self.layer addSublayer:_middleCircle];

    _largeCircle = [CAShapeLayer layer];
    _largeCircle.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2) radius:largeCircleRadius startAngle:0 endAngle:M_PI * 2 clockwise:YES].CGPath;
    
    // Configure the apperence of the circle
    _largeCircle.fillColor = [UIColor clearColor].CGColor;
    _largeCircle.strokeColor = _strokeColor.CGColor;
    _largeCircle.lineWidth = 1;
    _largeCircle.lineDashPattern = @[@1, @1];
    [self.layer addSublayer:_largeCircle];
}

- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    [super sendAction:action to:target forEvent:target];
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    if (selected) {
        _strokeColor = [UIColor colorWithRed:0xff / 255.f green:0xc5 / 255.f blue:0x02 / 255.f alpha:1];
    } else {
        _strokeColor = [UIColor colorWithRed:0xff / 255.f green:0xff / 255.f blue:0xff / 255.f alpha:1];
    }
    _smallCircle.strokeColor = _strokeColor.CGColor;
    _middleCircle.strokeColor = _strokeColor.CGColor;
    _largeCircle.strokeColor = _strokeColor.CGColor;
}
@end
