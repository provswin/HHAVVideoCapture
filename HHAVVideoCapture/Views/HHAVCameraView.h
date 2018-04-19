//
//  HHAVCameraView.h
//  HHAVVideoCapture
//
//  Created by 胡华翔 on 2018/3/29.
//  Copyright © 2018年 胡华翔. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HHAVPreviewView.h"
#import "HHAVOverlayView.h"

@class AVCaptureSession;

@interface HHAVCameraView : UIView
/* 预览视图 */
@property (weak, nonatomic) IBOutlet HHAVPreviewView *previewView;

/* 浮层视图 */
@property (weak, nonatomic) IBOutlet HHAVOverlayView *overlayView;
@end
