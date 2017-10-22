//
//  TrackedObject.swift
//  Help Me Be Social
//
//  Created by Venkatesh Sivaraman on 10/21/17.
//  Copyright © 2017 Hack Harvard 2017. All rights reserved.
//

import UIKit

class TrackedObject: NSObject {
    private static var objectIDCount = 0
    
    var bounds: CGRect
    var objectID: Int
    
    // Add properties here from Facebook query
    var personName: String?
    
    init(bounds: CGRect) {
        self.bounds = bounds
        self.objectID = TrackedObject.objectIDCount
        TrackedObject.objectIDCount += 1
    }
}
