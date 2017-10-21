//
//  FaceOverlayView.swift
//  Help Me Be Social
//
//  Created by Venkatesh Sivaraman on 10/20/17.
//  Copyright © 2017 Hack Harvard 2017. All rights reserved.
//

import UIKit

class FaceOverlayView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    var borderColor = UIColor(red: 84.0/255.0, green: 187.0/255.0, blue: 247.0/255.0, alpha: 1.0)
    var fillColor = UIColor(red: 84.0/255.0, green: 187.0/255.0, blue: 247.0/255.0, alpha: 1.0).withAlphaComponent(0.3)
    
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        
        let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: UIRectCorner.allCorners, cornerRadii: CGSize(width: 6.0, height: 6.0))
        path.lineWidth = 2.0
        borderColor.setStroke()
        fillColor.setFill()
        path.fill()
        path.stroke()
    }
    
}
