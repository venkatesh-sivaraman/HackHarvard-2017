//
//  DetectedFace.swift
//  Help Me Be Social
//
//  Created by Venkatesh Sivaraman on 10/20/17.
//  Copyright © 2017 Hack Harvard 2017. All rights reserved.
//

import UIKit

class DetectedFace: NSObject {
    
    private static var faceIDCount = 0
    
    var feature: CIFaceFeature
    var faceID: Int
    
    // Add properties here from Facebook query
    
    init(feature: CIFaceFeature) {
        self.feature = feature
        self.faceID = DetectedFace.faceIDCount
        DetectedFace.faceIDCount += 1
    }

}
