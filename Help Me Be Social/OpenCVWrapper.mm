//
//  OpenCVWrapper.m
//  Help Me Be Social
//
//  Created by Venkatesh Sivaraman on 10/21/17.
//  Copyright © 2017 Hack Harvard 2017. All rights reserved.
//

#import <opencv2/opencv.hpp>
#import <opencv2/videoio/cap_ios.h>
#import <opencv2/imgcodecs/imgcodecs.hpp>
#import <opencv2/imgcodecs/ios.h>
#import "OpenCVWrapper.h"

using namespace std;

@interface OpenCVWrapper ()

@property (nonatomic, strong) CIContext *context;

@end

@implementation OpenCVWrapper

-(cv::Mat)cvMatWithImage:(CIImage *)image
{
    if (self.context == nil) {
        self.context = [[CIContext alloc] init];
    }
    CGImageRef cgImage = [self.context createCGImage:image fromRect:image.extent];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat cols = CGImageGetWidth(cgImage), rows = CGImageGetHeight(cgImage);
    CGContextRef contextRef;
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast;
    BOOL alphaExist = NO;
    
    cv::Mat m;
    if (CGColorSpaceGetModel(colorSpace) == kCGColorSpaceModelMonochrome)
    {
        m.create(rows, cols, CV_8UC1); // 8 bits per component, 1 channel
        bitmapInfo = kCGImageAlphaNone;
        if (!alphaExist)
            bitmapInfo = kCGImageAlphaNone;
        else
            m = cv::Scalar(0);
        contextRef = CGBitmapContextCreate(m.data, m.cols, m.rows, 8,
                                           m.step[0], colorSpace,
                                           bitmapInfo);
    }
    else
    {
        m.create(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
        if (!alphaExist)
            bitmapInfo = kCGImageAlphaNoneSkipLast |
            kCGBitmapByteOrderDefault;
        else
            m = cv::Scalar(0);
        contextRef = CGBitmapContextCreate(m.data, m.cols, m.rows, 8,
                                           m.step[0], colorSpace,
                                           bitmapInfo);
    }
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows),
                       cgImage);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(cgImage);
    return m;
}

-(CIImage *)imageFromCVMat:(cv::Mat)cvMat {
    NSData *data = [NSData dataWithBytes:cvMat.data
                                  length:cvMat.step.p[0] * cvMat.rows];
    
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider =
    CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Preserve alpha transparency, if exists
    bool alpha = cvMat.channels() == 4;
    CGBitmapInfo bitmapInfo = (alpha ? kCGImageAlphaLast : kCGImageAlphaNone) | kCGBitmapByteOrderDefault;
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,
                                        cvMat.rows,
                                        8 * cvMat.elemSize1(),
                                        8 * cvMat.elemSize(),
                                        cvMat.step.p[0],
                                        colorSpace,
                                        bitmapInfo,
                                        provider,
                                        NULL,
                                        false,
                                        kCGRenderingIntentDefault
                                        );
    
    
    // Getting UIImage from CGImage
    CIImage *finalImage = [CIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

-(CIImage *)addTextToImage:(CIImage *)originalImage
{
    cv::Mat matRepresentation = [self cvMatWithImage:originalImage];
    const char* str = [@"Hola Mundo" cStringUsingEncoding: NSUTF8StringEncoding];
    cv::putText(matRepresentation, str, cv::Point(100, 100), CV_FONT_HERSHEY_PLAIN, 2.0, cv::Scalar(0, 0, 255));
    return [self imageFromCVMat:matRepresentation];
}

-(cv::Mat)hsvRepresentationOfMat:(cv::Mat)mat
{
    cv::Mat bgrROI;
    cv::cvtColor(mat, bgrROI, cv::COLOR_RGBA2BGR);
    cv::Mat hsvROI;
    cv::cvtColor(bgrROI, hsvROI, cv::COLOR_BGR2HSV);
    return hsvROI;
}

-(void)debugCIImageOfMat:(cv::Mat)mat
{
    CIImage *img = [self imageFromCVMat:mat];
    NSLog(@"Img: %@", img);
}

-(CGRect)trackObjectInRect:(CGRect)bounds inImage:(CIImage *)image1 nextImage:(CIImage *)image2
{
    cv::Mat mat1 = [self cvMatWithImage:image1];
    CGRect clampedBounds = CGRectMake(bounds.origin.x, image1.extent.size.height - bounds.origin.y - bounds.size.height,
                                      bounds.size.width, bounds.size.height);
    CGPoint topLeft = CGPointMake(max(min(clampedBounds.origin.x, image1.extent.size.width), 0.0), max(min(clampedBounds.origin.y, image1.extent.size.height), 0.0));
    CGPoint bottomRight = CGPointMake(max(min(clampedBounds.origin.x + clampedBounds.size.width, image1.extent.size.width), 0.0), max(min(clampedBounds.origin.y + clampedBounds.size.height, image1.extent.size.height), 0.0));
    clampedBounds = CGRectMake(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y);
    if (clampedBounds.size.width <= 5.0 || clampedBounds.size.height <= 5.0) {
        return CGRectZero;
    }
    cv::Mat roi = mat1(cv::Range((int)clampedBounds.origin.y,
                         (int)clampedBounds.origin.y + (int)clampedBounds.size.height),
               cv::Range((int)clampedBounds.origin.x,
                         (int)clampedBounds.origin.x + (int)clampedBounds.size.width));
    //[self debugCIImageOfMat:roi];

    cv::Mat hsvROI = [self hsvRepresentationOfMat:roi];
    //cv::Mat mask;
    //cv::inRange(hsvROI, cv::Scalar(0, 60, 32), cv::Scalar(180, 255, 255), mask);
    
    cv::Mat roiHist;
    const int histSize = 180;
    const int channelIndex = 0;
    float range[] = { 0, 256 };
    const float* histRange = { range };
    cv::calcHist(&hsvROI, 1, &channelIndex, cv::Mat(), roiHist, 1, &histSize, &histRange);
    cv::normalize(roiHist, roiHist, 0, 255, cv::NORM_MINMAX);
    
    cv::Mat hsvROI2 = [self hsvRepresentationOfMat:[self cvMatWithImage:image2]];
    cv::Mat backProject;
    cv::calcBackProject(&hsvROI2, 1, &channelIndex, roiHist, backProject, &histRange);
    
    cv::Rect window = cv::Rect(clampedBounds.origin.x, clampedBounds.origin.y, clampedBounds.size.width, clampedBounds.size.height);
    cv::RotatedRect result = cv::CamShift(backProject, window, cv::TermCriteria( cv::TermCriteria::EPS | cv::TermCriteria::COUNT, 10, 1 ));
    CGRect resultRect = CGRectMake((result.center.x - result.size.width / 2.0 - 10.0), (image1.extent.size.height - result.center.y - result.size.height / 2.0 - 10.0), result.size.width, result.size.height);
    return CGRectMake(resultRect.origin.x + resultRect.size.width / 2.0 - clampedBounds.size.width / 2.0, resultRect.origin.y + resultRect.size.height / 2.0 - clampedBounds.size.height / 2.0, clampedBounds.size.width, clampedBounds.size.height);
}

@end
