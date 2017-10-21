//
//  OpenCVWrapper.h
//  Help Me Be Social
//
//  Created by Venkatesh Sivaraman on 10/21/17.
//  Copyright © 2017 Hack Harvard 2017. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface OpenCVWrapper : NSObject

-(NSObject *)newCameraViewWithParentView:(UIView *)parent;
-(void)layoutPreviewLayerForCamera:(NSObject *)camera;

@end
