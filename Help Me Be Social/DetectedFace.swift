//
//  DetectedFace.swift
//  Help Me Be Social
//
//  Created by Venkatesh Sivaraman on 10/20/17.
//  Copyright © 2017 Hack Harvard 2017. All rights reserved.
//

import UIKit
import AVFoundation

class DetectedFace: NSObject {
    
    var faceID: Int = 0
    var metadataObject: AVMetadataFaceObject? {
        didSet {
            self.faceID = metadataObject?.faceID ?? 0
        }
    }
    
    // Add properties here from Facebook query
    
    init(object: AVMetadataFaceObject) {
        super.init()
        defer {
            self.metadataObject = object
        }
    }

}
