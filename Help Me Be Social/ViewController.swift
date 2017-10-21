//
//  ViewController.swift
//  Help Me Be Social
//
//  Created by Venkatesh Sivaraman on 10/20/17.
//  Copyright © 2017 Hack Harvard 2017. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var camera: NSObject?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        camera = OpenCVWrapper().newCameraView(withParentView: self.view)
    }
    
    override func viewDidLayoutSubviews() {
        if let cam = camera {
            OpenCVWrapper().layoutPreviewLayer(forCamera: cam)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

