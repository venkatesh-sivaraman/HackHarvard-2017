//
//  ObjectOverlayView.swift
//  Help Me Be Social
//
//  Created by Venkatesh Sivaraman on 10/21/17.
//  Copyright © 2017 Hack Harvard 2017. All rights reserved.
//

import UIKit

class ObjectOverlayView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    var borderColor = UIColor.white
    var fillColor = UIColor.white.withAlphaComponent(0.3)
    
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
