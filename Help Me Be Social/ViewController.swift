//
//  ViewController.swift
//  Help Me Be Social
//
//  Created by Venkatesh Sivaraman on 10/20/17.
//  Copyright © 2017 Hack Harvard 2017. All rights reserved.
//

import UIKit
import AVFoundation
import CoreImage

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var liveFeed: AVCaptureVideoPreviewLayer?
    var cameraSession: AVCaptureSession?
    var captureDevice: AVCaptureDevice?
    var outputObject: AVCaptureOutput?
    
    lazy var cvManager: OpenCVWrapper = OpenCVWrapper()
    
    lazy var lowAccuracyDetector: CIDetector? = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])
    lazy var highAccuracyDetector: CIDetector? = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    lazy var outputQueue: DispatchQueue = DispatchQueue(label: "helpmebesocial.camera-output")
    lazy var lowAccuracyQueue: DispatchQueue = DispatchQueue(label: "helpmebesocial.lo-fi-output")
    lazy var highAccuracyQueue: DispatchQueue = DispatchQueue(label: "helpmebesocial.hi-fi-output")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeVideoPreview()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraSession?.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraSession?.stopRunning()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Camera Setup
    
    func initializeVideoPreview() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
        guard let device = discoverySession.devices.first else {
            print("No recording device")
            return
        }
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            print("Couldn't get device input")
            return
        }
        session.addInput(input)
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: outputQueue)
        
        if session.canAddOutput(output) {
            session.addOutput(output)
            outputObject = output
        }
        
        session.commitConfiguration()
        
        let feedLayer = AVCaptureVideoPreviewLayer(session: session)
        view.layer.addSublayer(feedLayer)
        
        captureDevice = device
        liveFeed = feedLayer
        cameraSession = session
    }
    
    private func updateVideoConnection(_ connection: AVCaptureConnection, with orientation: AVCaptureVideoOrientation) {
        connection.videoOrientation = orientation
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        liveFeed?.frame = view.layer.bounds
        
        if let connection = liveFeed?.connection  {
            let currentDevice: UIDevice = UIDevice.current
            let orientation: UIDeviceOrientation = currentDevice.orientation
            let previewLayerConnection: AVCaptureConnection = connection
            if previewLayerConnection.isVideoOrientationSupported {
                switch (orientation) {
                case .portrait: updateVideoConnection(previewLayerConnection, with: .portrait)
                case .landscapeRight: updateVideoConnection(previewLayerConnection, with: .landscapeLeft)
                case .landscapeLeft: updateVideoConnection(previewLayerConnection, with: .landscapeRight)
                case .portraitUpsideDown: updateVideoConnection(previewLayerConnection, with: .portraitUpsideDown)
                default: updateVideoConnection(previewLayerConnection, with: .portrait)
                }
            }
        }
    }
    
    // MARK: - Getting Sample Output
    
    enum EXIFOrientation: Int {
        case PHOTOS_EXIF_0ROW_TOP_0COL_LEFT          = 1 //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
        case PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT         = 2 //   2  =  0th row is at the top, and 0th column is on the right.
        case PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3 //   3  =  0th row is at the bottom, and 0th column is on the right.
        case PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4 //   4  =  0th row is at the bottom, and 0th column is on the left.
        case PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5 //   5  =  0th row is on the left, and 0th column is the top.
        case PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6 //   6  =  0th row is on the right, and 0th column is the top.
        case PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7 //   7  =  0th row is on the right, and 0th column is the bottom.
        case PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8 //   8  =  0th row is on the left, and 0th column is the bottom.
    }
    
    func exifOrientation(orientation: UIDeviceOrientation) -> Int {
        var exif: EXIFOrientation
        
        /* kCGImagePropertyOrientation values
         The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
         by the TIFF and EXIF specifications -- see enumeration of integer constants.
         The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
         
         used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
         If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
        
        let isUsingFrontFacingCamera = (captureDevice != nil && captureDevice?.position != .back)
        
        switch (orientation) {
        case .portraitUpsideDown:  // Device oriented vertically, home button on the top
            exif = .PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM
        case .landscapeLeft:       // Device oriented horizontally, home button on the right
            if (isUsingFrontFacingCamera) {
                exif = .PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT
            } else {
                exif = .PHOTOS_EXIF_0ROW_TOP_0COL_LEFT
            }
        case .landscapeRight:      // Device oriented horizontally, home button on the left
            if (isUsingFrontFacingCamera) {
                exif = .PHOTOS_EXIF_0ROW_TOP_0COL_LEFT
            } else {
                exif = .PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT
            }
        // Device oriented vertically, home button on the bottom
        default:
            exif = .PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP
        }
        
        return exif.rawValue
    }
    
    var frameIndex: Int = 0
    var frameInterval = 2
    
    var lastImage: CIImage?
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [String : Any]?)
        frameIndex = (frameIndex + 1) % frameInterval
        if lastImage == nil {
            lastImage = ciImage
        }
        if frameIndex == 0 {
            trackObjects(in: ciImage)
        }
        
        
        //updateWithLowAccuracyFeatures(from: ciImage)
    }
    
    func getLowAccuracyFeatures(from image: CIImage) -> [CGRect] {
        let options: [String : Any] = [CIDetectorImageOrientation: self.exifOrientation(orientation: UIDevice.current.orientation)]
        guard let features = self.lowAccuracyDetector?.features(in: image, options: options) else {
            print("Couldn't get high-accuracy features")
            return []
        }
        print("Detected \(features.count) faces in high accuracy")
        // Grab the frames for each face
        /*for face in currentFaces {
         let croppedImage = ciImage.cropped(to: face.feature.bounds)
         }*/
        return features.flatMap { ($0 as? CIFaceFeature)?.bounds }
    }

    func trackObjects(in image: CIImage) {
        guard let last = lastImage else {
            return
        }
        highAccuracyQueue.async {
            let targets = self.getLowAccuracyFeatures(from: last)
            var newObjects: [TrackedObject] = []
            var processedObjects: [TrackedObject] = []
            for target in targets {
                var existing: TrackedObject?
                for existingObject in self.trackedObjects {
                    let center = CGPoint(x: existingObject.bounds.midX, y: existingObject.bounds.midY)
                    if sqrt(pow(center.x - target.midX, 2.0) + pow(center.y - target.midY, 2.0)) < max(existingObject.bounds.size.width * 2.0, existingObject.bounds.size.height * 2.0) {
                        existing = existingObject
                        break
                    }
                }
                if let existingObj = existing {
                    processedObjects.append(existingObj)
                    existingObj.bounds = target
                    DispatchQueue.main.async {
                        self.displayedObjectLayers[existingObj]?.borderColor = UIColor.blue
                        self.displayedObjectLayers[existingObj]?.fillColor = UIColor.blue.withAlphaComponent(0.2)
                        self.updateLayer(for: existingObj)
                    }
                } else {
                    let newRect = self.cvManager.trackObject(in: target, in: last, nextImage: image)
                    print(target, newRect)
                    let newTracked = TrackedObject(bounds: newRect)
                    newObjects.append(newTracked)
                    DispatchQueue.main.async {
                        self.addLayer(for: newTracked, color: UIColor.green)
                        self.update(object: newTracked, with: "Your Name")
                    }
                }
            }
            
            var objectsToRemove: [Int] = []
            print("Out of \(self.trackedObjects.count) objects, \(processedObjects.count) already processed with faces")
            for (i, existingObject) in self.trackedObjects.enumerated() where !processedObjects.contains(existingObject) {
                let target = existingObject.bounds
                let newRect = self.cvManager.trackObject(in: target, in: last, nextImage: image)
                if newRect.width * newRect.height >= 300.0 {
                    existingObject.bounds = newRect
                    DispatchQueue.main.async {
                        self.displayedObjectLayers[existingObject]?.borderColor = UIColor.green
                        self.displayedObjectLayers[existingObject]?.fillColor = UIColor.green.withAlphaComponent(0.2)
                        self.updateLayer(for: existingObject)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.removeLayer(for: existingObject)
                    }
                    objectsToRemove.append(i)
                }
            }
            for i in objectsToRemove.sorted().reversed() {
                self.trackedObjects.remove(at: i)
            }

            self.trackedObjects += newObjects
            //let img = cvManager.addText(to: image)
            //print(img)
            self.lastImage = image
            //self.coalesceTrackedObjects()
            
            DispatchQueue.main.async {
                self.view.setNeedsLayout()
                UIView.animate(withDuration: 0.2, delay: 0.0, options: .beginFromCurrentState, animations: {
                    self.view.layoutIfNeeded()
                }, completion: nil)
            }
        }
    }
    
    func coalesceTrackedObjects() {
        var objectSets: [[Int]] = []
        for (i, object) in self.trackedObjects.enumerated() {
            let area = object.bounds.width * object.bounds.height
            for (j, otherObject) in self.trackedObjects.enumerated() where otherObject != object {
                let otherArea = otherObject.bounds.width * otherObject.bounds.height
                let union = object.bounds.union(otherObject.bounds)
                if union.width * union.height <= (area + otherArea) * 0.75 {
                    objectSets.append([i, j])
                }
            }
        }
        
        // This is lazy - need to use union-find at some point
        var objectsToRemove: [Int] = []
        for set in objectSets {
            guard let selectedObject = set.first(where: { self.trackedObjects[$0].personName != nil }) ?? set.max(by: { self.trackedObjects[$0].bounds.width * self.trackedObjects[$0].bounds.height < self.trackedObjects[$1].bounds.width * self.trackedObjects[$1].bounds.height }),
                displayedObjectLayers[self.trackedObjects[selectedObject]] != nil else {
                continue
            }
            for obj in set where obj != selectedObject {
                DispatchQueue.main.async {
                    objectsToRemove.append(obj)
                    self.removeLayer(for: self.trackedObjects[obj])
                }
            }
        }
        for i in objectsToRemove.sorted().reversed() {
            self.trackedObjects.remove(at: i)
        }
    }
    
    // MARK: Highlighting Faces
    
    var displayedObjectConstraints: [TrackedObject: [NSLayoutConstraint]] = [:]
    var displayedObjectLayers: [TrackedObject: ObjectOverlayView] = [:]
    var displayedObjectLabels: [TrackedObject: NameOverlayView] = [:]
    var trackedObjects: [TrackedObject] = []
    
    func updateLayer(for object: TrackedObject, animated: Bool = true) {
        guard let layer = displayedObjectLayers[object] else {
            print("No layer for yo face!")
            return
        }
        guard let metadataBounds = outputObject?.metadataOutputRectConverted(fromOutputRect: object.bounds),
            var convertedBounds = liveFeed?.layerRectConverted(fromMetadataOutputRect: metadataBounds) else {
                return
        }
        if let previewLayer = liveFeed {
            if UIDevice.current.orientation.isLandscape {
                convertedBounds.origin.y = previewLayer.frame.size.height - convertedBounds.maxY
            } else {
                convertedBounds.origin.x = previewLayer.frame.size.width - convertedBounds.maxX
            }
        }
        /*if let oldConstraints = displayedObjectConstraints[object] {
            NSLayoutConstraint.deactivate(oldConstraints)
        }
        let constraints = [layer.leftAnchor.constraint(equalTo: view.leftAnchor, constant: convertedBounds.origin.x),
                           layer.topAnchor.constraint(equalTo: view.topAnchor, constant: convertedBounds.origin.y),
                           layer.widthAnchor.constraint(equalToConstant: convertedBounds.size.width),
                           layer.heightAnchor.constraint(equalToConstant: convertedBounds.size.height)]
        NSLayoutConstraint.activate(constraints)
        displayedObjectConstraints[object] = constraints*/
        if !animated {
            layer.frame = convertedBounds
            layer.setNeedsDisplay()
        } else {
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .beginFromCurrentState, animations: {
                layer.frame = convertedBounds
                layer.setNeedsDisplay()
            }, completion: nil)
        }
    }
    
    func addLayer(for object: TrackedObject, color: UIColor? = nil) {
        let layer = ObjectOverlayView(frame: CGRect.zero)
        if let customColor = color {
            layer.borderColor = customColor
            layer.fillColor = customColor.withAlphaComponent(0.2)
        }
        //layer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(layer)
        displayedObjectLayers[object] = layer
        updateLayer(for: object, animated: false)
    }
    
    func removeLayer(for object: TrackedObject) {
        guard let layer = displayedObjectLayers[object] else {
            return
        }
        layer.removeFromSuperview()
        displayedObjectLayers[object] = nil
        removeNameLabel(for: object, animated: true)
    }
    
    func updateNameLabel(for object: TrackedObject) {
        guard let associatedRectangle = displayedObjectLayers[object] else {
            return
        }
        
        var label: NameOverlayView
        if let existingLabel = displayedObjectLabels[object] {
            label = existingLabel
        } else {
            label = NameOverlayView(frame: CGRect.zero)
            view.addSubview(label)
            label.centerXAnchor.constraint(equalTo: associatedRectangle.centerXAnchor).isActive = true
            label.topAnchor.constraint(equalTo: associatedRectangle.bottomAnchor, constant: 4.0).isActive = true
        }
        label.name = object.personName
        displayedObjectLabels[object] = label
    }
    
    func removeNameLabel(for object: TrackedObject, animated: Bool = false) {
        guard let label = displayedObjectLabels[object] else {
            return
        }
        
        displayedObjectLabels[object] = nil
        if animated {
            UIView.animate(withDuration: 0.2, animations: {
                label.alpha = 0.0
            }, completion: { (completed) in
                if completed {
                    label.removeFromSuperview()
                }
            })
        } else {
            label.removeFromSuperview()
        }
    }
    
    // MARK: - Tagging Objects with Names
    
    func update(object: TrackedObject, with name: String) {
        object.personName = name
        updateNameLabel(for: object)
    }
}

