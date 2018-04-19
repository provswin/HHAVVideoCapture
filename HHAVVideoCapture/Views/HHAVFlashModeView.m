//
//  HHAVFlashModeView.m
//  HHAVVideoCapture
//
//  Created by 胡华翔 on 2018/4/2.
//  Copyright © 2018年 胡华翔. All rights reserved.
//

#import "HHAVFlashModeView.h"

@implementation HHAVFlashModeView
- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        UIView *nib = [[[NSBundle mainBundle] loadNibNamed:@"HHAVFlashModeView" owner:self options:nil] objectAtIndex:0];
        [self addSubview:nib];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
}

- (void)initViewWithMode:(HHAVFlashMode)mode {
    switch (mode) {
        case HHAVFlashModeOn:
            self.modeAutoButton.selected = NO;
            self.modeOnButton.selected = YES;
            self.modeOffButton.selected = NO;
            break;
        case HHAVFlashModeOff:
            self.modeAutoButton.selected = NO;
            self.modeOnButton.selected = NO;
            self.modeOffButton.selected = YES;
            break;
        case HHAVFlashModeAuto:
            self.modeAutoButton.selected = YES;
            self.modeOnButton.selected = NO;
            self.modeOffButton.selected = NO;
            break;
    }
}

@end
