//
//  OpenCVWrapper.h
//  Help Me Be Social
//
//  Created by Venkatesh Sivaraman on 10/21/17.
//  Copyright © 2017 Hack Harvard 2017. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface OpenCVWrapper : NSObject

-(CIImage *)addTextToImage:(CIImage *)originalImage;
-(CGRect)trackObjectInRect:(CGRect)bounds inImage:(CIImage *)image1 nextImage:(CIImage *)image2;

@end
