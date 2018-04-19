//
//  HHAVCaptureButton.h
//  HHAVVideoCapture
//
//  Created by 胡华翔 on 2018/3/29.
//  Copyright © 2018年 胡华翔. All rights reserved.
//

#import <UIKit/UIKit.h>

/* 按钮状态 */
typedef NS_ENUM( NSInteger, HHAVCaptureButtonStatus ) {
    HHAVCaptureButtonStatusRecording,
    HHAVCaptureButtonStatusNotRecording,
    HHAVCaptureButtonStatusPhoto
};

@interface HHAVCaptureButton : UIButton
- (void)changeButtonWithButtonStatus:(HHAVCaptureButtonStatus)status previousStatus:(HHAVCaptureButtonStatus)previousStatus;
@end
