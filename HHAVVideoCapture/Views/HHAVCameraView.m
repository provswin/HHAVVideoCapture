//
//  HHAVCameraView.m
//  HHAVVideoCapture
//
//  Created by 胡华翔 on 2018/3/29.
//  Copyright © 2018年 胡华翔. All rights reserved.
//

#import "HHAVCameraView.h"
#import <AVFoundation/AVFoundation.h>
@interface HHAVCameraView ()

@end

@implementation HHAVCameraView
- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        UIView *nib = [[[NSBundle mainBundle] loadNibNamed:@"HHAVCameraView" owner:self options:nil] objectAtIndex:0];
        [self addSubview:nib];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    self.backgroundColor = [UIColor blackColor];
    _previewView.overlayView = _overlayView;
}
@end
