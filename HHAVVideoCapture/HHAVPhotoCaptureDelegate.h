/*
See LICENSE.txt for this sample’s licensing information.

Abstract:
Photo capture delegate.
*/

@import AVFoundation;

@interface HHAVPhotoCaptureDelegate : NSObject<AVCapturePhotoCaptureDelegate>

- (instancetype)initWithRequestedPhotoSettings:(AVCapturePhotoSettings *)requestedPhotoSettings willCapturePhotoAnimation:(void (^)(void))willCapturePhotoAnimation livePhotoCaptureHandler:(void (^)(BOOL capturing))livePhotoCaptureHandler completionHandler:(void (^)(HHAVPhotoCaptureDelegate *photoCaptureDelegate, NSData *imageData))completionHandler;

@property (nonatomic, readonly) AVCapturePhotoSettings *requestedPhotoSettings;

@end
