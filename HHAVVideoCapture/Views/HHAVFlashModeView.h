//
//  HHAVFlashModeView.h
//  HHAVVideoCapture
//
//  Created by 胡华翔 on 2018/4/2.
//  Copyright © 2018年 胡华翔. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, HHAVFlashMode) {
    HHAVFlashModeOff  = 0,
    HHAVFlashModeOn   = 1,
    HHAVFlashModeAuto = 2,
};

@interface HHAVFlashModeView : UIView
@property (weak, nonatomic) IBOutlet UIButton *modeAutoButton;
@property (weak, nonatomic) IBOutlet UIButton *modeOnButton;
@property (weak, nonatomic) IBOutlet UIButton *modeOffButton;

/**
 初始化视图,用于确定应该默认高亮哪个Button

 @param mode 闪光灯模式
 */
- (void)initViewWithMode:(HHAVFlashMode)mode;
@end
