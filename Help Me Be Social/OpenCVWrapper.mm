//
//  OpenCVWrapper.m
//  Help Me Be Social
//
//  Created by Venkatesh Sivaraman on 10/21/17.
//  Copyright © 2017 Hack Harvard 2017. All rights reserved.
//

#import <opencv2/opencv.hpp>
#import <opencv2/videoio/cap_ios.h>
#import "OpenCVWrapper.h"
#import <AVFoundation/AVFoundation.h>

using namespace std;

@implementation OpenCVWrapper

-(NSObject *)newCameraViewWithParentView:(UIView *)parent
{
    CvVideoCamera *camera = [[CvVideoCamera alloc] initWithParentView:parent];
    camera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    camera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
    camera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    camera.defaultFPS = 30;
    camera.grayscaleMode = NO;
    //camera.delegate = self;
    [camera start];
    return camera;
}

-(void)layoutPreviewLayerForCamera:(NSObject *)camera
{
    if ([camera isKindOfClass:[CvVideoCamera class]]) {
        [(CvVideoCamera *)camera layoutPreviewLayer];
    }
}

@end
