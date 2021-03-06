/*
See LICENSE.txt for this sample’s licensing information.

Abstract:
Photo capture delegate.
*/


#import "HHAVPhotoCaptureDelegate.h"

@import Photos;

@interface HHAVPhotoCaptureDelegate () <AVCapturePhotoCaptureDelegate>

@property (nonatomic, readwrite) AVCapturePhotoSettings *requestedPhotoSettings;
@property (nonatomic) void (^willCapturePhotoAnimation)(void);
@property (nonatomic) void (^livePhotoCaptureHandler)(BOOL capturing);
@property(nonatomic) void (^completionHandler)(HHAVPhotoCaptureDelegate *photoCaptureDelegate, NSData *imageData);

@property (nonatomic) NSData *photoData;
@property (nonatomic) NSURL *livePhotoCompanionMovieURL;

@end

@implementation HHAVPhotoCaptureDelegate

- (instancetype)initWithRequestedPhotoSettings:(AVCapturePhotoSettings *)requestedPhotoSettings willCapturePhotoAnimation:(void (^)(void))willCapturePhotoAnimation livePhotoCaptureHandler:(void (^)(BOOL))livePhotoCaptureHandler completionHandler:(void (^)(HHAVPhotoCaptureDelegate *, NSData *))completionHandler
{
	self = [super init];
	if ( self ) {
		self.requestedPhotoSettings = requestedPhotoSettings;
		self.willCapturePhotoAnimation = willCapturePhotoAnimation;
		self.livePhotoCaptureHandler = livePhotoCaptureHandler;
		self.completionHandler = completionHandler;
	}
	return self;
}

- (void)didFinish
{
	if ( [[NSFileManager defaultManager] fileExistsAtPath:self.livePhotoCompanionMovieURL.path] ) {
		NSError *error = nil;
		[[NSFileManager defaultManager] removeItemAtPath:self.livePhotoCompanionMovieURL.path error:&error];
		
		if ( error ) {
			NSLog( @"Could not remove file at url: %@", self.livePhotoCompanionMovieURL.path );
		}
	}

    self.completionHandler(self, self.photoData);
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput willBeginCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
{
	if ( ( resolvedSettings.livePhotoMovieDimensions.width > 0 ) && ( resolvedSettings.livePhotoMovieDimensions.height > 0 ) ) {
		self.livePhotoCaptureHandler( YES );
	}
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput willCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
{
	self.willCapturePhotoAnimation();
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishProcessingPhotoSampleBuffer:(CMSampleBufferRef)photoSampleBuffer previewPhotoSampleBuffer:(CMSampleBufferRef)previewPhotoSampleBuffer resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings error:(NSError *)error {
    if (error) {
        NSLog(@"error : %@", error.localizedDescription);
    }

    if (photoSampleBuffer) {
        self.photoData = [AVCapturePhotoOutput JPEGPhotoDataRepresentationForJPEGSampleBuffer:photoSampleBuffer previewPhotoSampleBuffer:previewPhotoSampleBuffer];
    }
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishRecordingLivePhotoMovieForEventualFileAtURL:(NSURL *)outputFileURL resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
{
	self.livePhotoCaptureHandler(NO);
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishProcessingLivePhotoToMovieFileAtURL:(NSURL *)outputFileURL duration:(CMTime)duration photoDisplayTime:(CMTime)photoDisplayTime resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings error:(NSError *)error
{
	if ( error != nil ) {
		NSLog( @"Error processing live photo companion movie: %@", error );
		return;
	}
	
	self.livePhotoCompanionMovieURL = outputFileURL;
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings error:(NSError *)error
{
	if ( error != nil ) {
		NSLog( @"Error capturing photo: %@", error );
		[self didFinish];
		return;
	}
	
	if ( self.photoData == nil ) {
		NSLog( @"No photo data resource" );
		[self didFinish];
		return;
	}
	
	[PHPhotoLibrary requestAuthorization:^( PHAuthorizationStatus status ) {
		if ( status == PHAuthorizationStatusAuthorized ) {
			[[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
				PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                if (@available(iOS 11.0, *)) {
                    options.uniformTypeIdentifier = self.requestedPhotoSettings.processedFileType;
                } else {
                    options.uniformTypeIdentifier = @"public.jpeg";
                }
				PHAssetCreationRequest *creationRequest = [PHAssetCreationRequest creationRequestForAsset];
				[creationRequest addResourceWithType:PHAssetResourceTypePhoto data:self.photoData options:options];
				
				if ( self.livePhotoCompanionMovieURL ) {
					PHAssetResourceCreationOptions *livePhotoCompanionMovieResourceOptions = [[PHAssetResourceCreationOptions alloc] init];
					livePhotoCompanionMovieResourceOptions.shouldMoveFile = YES;
					[creationRequest addResourceWithType:PHAssetResourceTypePairedVideo fileURL:self.livePhotoCompanionMovieURL options:livePhotoCompanionMovieResourceOptions];
				}
			} completionHandler:^( BOOL success, NSError * _Nullable error ) {
				if ( ! success ) {
					NSLog( @"Error occurred while saving photo to photo library: %@", error );
				}
				
				[self didFinish];
			}];
		}
		else {
			NSLog( @"Not authorized to save photo" );
			[self didFinish];
		}
	}];
}

@end
