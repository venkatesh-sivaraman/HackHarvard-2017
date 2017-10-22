//
//  NameOverlayView.swift
//  Help Me Be Social
//
//  Created by Venkatesh Sivaraman on 10/21/17.
//  Copyright © 2017 Hack Harvard 2017. All rights reserved.
//

import UIKit

class NameOverlayView: UIView {

    lazy var label: UILabel = {
        let lab = UILabel(frame: self.bounds)
        lab.textColor = UIColor.white
        lab.textAlignment = .center
        lab.font = UIFont.boldSystemFont(ofSize: 14.0)
        lab.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lab)
        let margin = CGFloat(4.0)
        self.leftAnchor.constraint(equalTo: lab.leftAnchor, constant: -margin).isActive = true
        self.rightAnchor.constraint(equalTo: lab.rightAnchor, constant: margin).isActive = true
        self.topAnchor.constraint(equalTo: lab.topAnchor, constant: -margin).isActive = true
        self.bottomAnchor.constraint(equalTo: lab.bottomAnchor, constant: margin).isActive = true
        return lab
    }()
    
    var name: String? {
        didSet {
            label.text = name
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor(white: 0.0, alpha: 0.9)
        self.layer.cornerRadius = 4.0
        self.translatesAutoresizingMaskIntoConstraints = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
