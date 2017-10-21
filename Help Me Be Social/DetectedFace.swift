//
//  DetectedFace.swift
//  Help Me Be Social
//
//  Created by Venkatesh Sivaraman on 10/20/17.
//  Copyright © 2017 Hack Harvard 2017. All rights reserved.
//

import UIKit

class DetectedFace: NSObject {
    
    var feature: CIFaceFeature
    
    // Add properties here from Facebook query
    
    init(feature: CIFaceFeature) {
        self.feature = feature
    }

}
