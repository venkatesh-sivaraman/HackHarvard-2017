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
    
    static let objectTrackingColor = UIColor(red: 84.0/255.0, green: 187.0/255.0, blue: 247.0/255.0, alpha: 1.0)
    static let faceRecognitionColor = UIColor(red: 123.0/255.0, green: 23.0/255.0, blue: 216.0/255.0, alpha: 1.0)
    static let barColor = UIColor(red: 123.0/255.0, green: 23.0/255.0, blue: 216.0/255.0, alpha: 1.0)
    
    var liveFeed: AVCaptureVideoPreviewLayer?
    var cameraSession: AVCaptureSession?
    var captureDevice: AVCaptureDevice?
    var outputObject: AVCaptureOutput?
    
    lazy var cvManager: OpenCVWrapper = OpenCVWrapper()
    
    lazy var lowAccuracyDetector: CIDetector? = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])
    lazy var highAccuracyDetector: CIDetector? = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    lazy var outputQueue: DispatchQueue = DispatchQueue(label: "helpmebesocial.camera-output")
    lazy var lowAccuracyQueue: DispatchQueue = DispatchQueue(label: "helpmebesocial.lo-fi-output")
    lazy var highAccuracyQueue: DispatchQueue = DispatchQueue(label: "helpmebesocial.hi-fi-output", qos: .background, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeVideoPreview()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraSession?.startRunning()
        navigationController?.setNavigationBarHidden(true, animated: true)
        navigationController?.setToolbarHidden(true, animated: true)
        navigationController?.navigationBar.barTintColor = ViewController.barColor
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.toolbar.barTintColor = ViewController.barColor
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.toolbar.tintColor = UIColor.white
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
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
    var frameInterval = 5
    
    var captureFrameIndex = 0
    var captureFrameInterval = 40
    
    var frameSequence: [CIImage] = []
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [String : Any]?)
        frameIndex = (frameIndex + 1) % frameInterval
        if frameIndex <= 1 {
            frameSequence.append(ciImage)
        }
        if frameIndex == 1, frameSequence.count > 1 {
            trackObjects(in: frameSequence)
            frameSequence = [ciImage]
        }
        
        if captureFrameIndex == captureFrameInterval / 2 {
            sendFrameToServer(ciImage)
        }
        captureFrameIndex = (captureFrameIndex + 1) % captureFrameInterval
        //updateWithLowAccuracyFeatures(from: ciImage)
    }
    
    func getLowAccuracyFeatures(from image: CIImage) -> [CGRect] {
        let options: [String : Any] = [CIDetectorImageOrientation: self.exifOrientation(orientation: UIDevice.current.orientation)]
        guard let features = self.lowAccuracyDetector?.features(in: image, options: options) else {
            print("Couldn't get high-accuracy features")
            return []
        }
        // Grab the frames for each face
        /*for face in currentFaces {
         let croppedImage = ciImage.cropped(to: face.feature.bounds)
         }*/
        return features.flatMap { ($0 as? CIFaceFeature)?.bounds }
    }
    
    var currentlyComputing = false

    func trackObjects(in imageSequence: [CIImage]) {
        guard imageSequence.count >= 2, !currentlyComputing else {
            return
        }
        highAccuracyQueue.async {
            self.currentlyComputing = true
            var lastFrame: CIImage?
            let oldObjects = Set<TrackedObject>(self.trackedObjects)
            var lastResult: [TrackedObject: Bool] = [:]
            for frame in imageSequence {
                guard let last = lastFrame else {
                    lastFrame = frame
                    continue
                }
                lastResult = self.updateTrackedObjects(from: last, to: frame)
                self.trackedObjects = lastResult.keys.filter({ $0.bounds != CGRect.zero })
                lastFrame = frame
            }
            self.coalesceTrackedObjects(with: lastResult)
            DispatchQueue.main.async {
                let newObjects = Set<TrackedObject>(self.trackedObjects)
                for obj in newObjects.subtracting(oldObjects) {
                    // Add these
                    self.addLayer(for: obj, color: lastResult[obj] == true ? ViewController.faceRecognitionColor : ViewController.objectTrackingColor)
                    //self.update(object: obj, with: "Your Name")
                }
                for obj in newObjects.intersection(oldObjects) {
                    guard oldObjects.contains(obj) else {
                        self.removeLayer(for: obj)
                        continue
                    }
                    if let resultDerivation = lastResult[obj] {
                        if resultDerivation {
                            // Face detection
                            self.displayedObjectLayers[obj]?.borderColor = ViewController.faceRecognitionColor
                            self.displayedObjectLayers[obj]?.fillColor = ViewController.faceRecognitionColor.withAlphaComponent(0.2)
                        } else {
                            // Object tracking
                            self.displayedObjectLayers[obj]?.borderColor = ViewController.objectTrackingColor
                            self.displayedObjectLayers[obj]?.fillColor = ViewController.objectTrackingColor.withAlphaComponent(0.2)
                        }
                    }
                    self.updateLayer(for: obj)
                }
                for obj in oldObjects.subtracting(newObjects) {
                    // Delete these
                    self.removeLayer(for: obj)
                }
            }
            self.currentlyComputing = false
        }
    }
    
    /// Values in the returned dictionary indicate whether the value was computed by face detection or not.
    func updateTrackedObjects(from lastImage: CIImage, to image: CIImage) -> [TrackedObject: Bool] {
        let targets = self.getLowAccuracyFeatures(from: lastImage)
        var newObjects: [TrackedObject] = []
        var ret: [TrackedObject: Bool] = [:]
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
                existingObj.bounds = target
                ret[existingObj] = true
            } else {
                let newRect = self.cvManager.trackObject(in: target, in: lastImage, nextImage: image)
                print(target, newRect)
                let newTracked = TrackedObject(bounds: newRect)
                newObjects.append(newTracked)
                ret[newTracked] = false
            }
        }
        
        for existingObject in self.trackedObjects where ret[existingObject] == nil {
            let target = existingObject.bounds
            let newRect = self.cvManager.trackObject(in: target, in: lastImage, nextImage: image)
            if newRect.width * newRect.height >= 300.0 {
                existingObject.bounds = newRect
                ret[existingObject] = false
            } else {
                existingObject.bounds = newRect
            }
        }
        return ret
    }
    
    func coalesceTrackedObjects(with priorities: [TrackedObject: Bool]) {
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
            guard let selectedObject = set.first(where: { priorities[self.trackedObjects[$0]] == true }) ?? set.first(where: { self.trackedObjects[$0].personName != nil }) ?? set.max(by: { self.trackedObjects[$0].bounds.width * self.trackedObjects[$0].bounds.height < self.trackedObjects[$1].bounds.width * self.trackedObjects[$1].bounds.height }),
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
        // Determine whether this rect is too close to the boundary of the image
        var newAlpha: CGFloat
        if layer.alpha < 0.9 {
            let inset = convertedBounds.insetBy(dx: -25.0, dy: -25.0)
            let edgeIntersection = inset.intersection(view.bounds)
            newAlpha = (edgeIntersection.width * edgeIntersection.height >= inset.width * inset.height) ? 1.0 : 0.1
        } else {
            let inset = convertedBounds.insetBy(dx: -15.0, dy: -15.0)
            let edgeIntersection = inset.intersection(view.bounds)
            newAlpha = (edgeIntersection.width * edgeIntersection.height / (inset.width * inset.height) < 0.9) ? 0.1 : 1.0
        }
        if !animated {
            layer.frame = convertedBounds
            layer.alpha = newAlpha
            layer.setNeedsDisplay()
        } else {
            UIView.animate(withDuration: 0.2, delay: 0.0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                layer.frame = convertedBounds
                layer.alpha = newAlpha
                layer.setNeedsDisplay()
            }, completion: nil)
        }
    }
    
    func addLayer(for object: TrackedObject, color: UIColor? = nil) {
        let layer = ObjectOverlayView(frame: CGRect.zero)
        let customColor = color ?? ViewController.objectTrackingColor
        layer.borderColor = customColor
        layer.fillColor = customColor.withAlphaComponent(0.2)
        layer.trackedObject = object
        //layer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(layer)
        displayedObjectLayers[object] = layer
        updateLayer(for: object, animated: false)
        
        let tapper = UITapGestureRecognizer(target: self, action: #selector(ViewController.detectedFaceTapped(_:)))
        layer.addGestureRecognizer(tapper)
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
        label.trackedObject = object
        let tapper = UITapGestureRecognizer(target: self, action: #selector(ViewController.detectedFaceTapped(_:)))
        label.addGestureRecognizer(tapper)
        displayedObjectLabels[object] = label
    }
    
    func removeNameLabel(for object: TrackedObject, animated: Bool = false) {
        guard let label = displayedObjectLabels[object] else {
            return
        }
        
        displayedObjectLabels[object] = nil
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0.0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
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
    
    // MARK: - Server Results
    
    struct ServerResult {
        var bounds: CGRect
        var name: String?
        var facebookID: String?
    }
    
    var pendingServerResult: Bool = false
    var serverPendingLocations: [TrackedObject: CGRect] = [:]
    
    func sendFrameToServer(_ ciImage: CIImage) {
        guard !pendingServerResult else {
            return
        }
        
        serverPendingLocations = [:]
        for obj in self.trackedObjects {
            serverPendingLocations[obj] = obj.bounds
        }
        if UIDevice.current.orientation.isPortrait {
            let size = CGSize(width: ciImage.extent.size.height, height: ciImage.extent.size.width)
            UIGraphicsBeginImageContext(size)
            UIImage(ciImage: ciImage, scale: 1.0, orientation: .right).draw(in: CGRect(origin: .zero, size: size))
        } else {
            UIGraphicsBeginImageContext(ciImage.extent.size)
            UIImage(ciImage: ciImage).draw(in: CGRect(origin: .zero, size: ciImage.extent.size))
        }
        guard let redraw = UIGraphicsGetImageFromCurrentImageContext() else { return }
        guard let imageData = UIImageJPEGRepresentation(redraw, 0.3) else {
            print("Couldn't get image data")
            UIGraphicsEndImageContext()
            return
        }
        UIGraphicsEndImageContext()
        guard let url = URL(string: "http://findfriendsdjango.azurewebsites.net/getimg") else {
            print("No url")
            return
        }
        let headers = [
            "content-type": "multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW",
            "cache-control": "no-cache",
            "postman-token": "c5d85566-dfeb-f93a-2c69-dc0753c3a19b"
        ]
        let parameters = [
            [
                "name": "file",
                "fileName": "img.jpg",
                "content-type": "image/jpeg"
            ]
        ]
        
        let boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
        
        var bodyData: Data?
        var body = ""
        for param in parameters {
            let paramName = param["name"]!
            body += "--\(boundary)\r\n"
            body += "Content-Disposition:form-data; name=\"\(paramName)\""
            if let filename = param["fileName"] {
                let contentType = param["content-type"]!
                body += "; filename=\"\(filename)\"\r\n"
                body += "Content-Type: \(contentType)\r\n\r\n"
                if let newData = body.data(using: .utf8) {
                    if bodyData != nil {
                        bodyData?.append(newData)
                    } else {
                        bodyData = newData
                    }
                    body = ""
                }
                bodyData?.append(imageData)
            } else if let paramValue = param["value"] {
                body += "\r\n\r\n\(paramValue)"
            }
        }
        if body.characters.count > 0, let newData = body.data(using: .utf8) {
            if bodyData != nil {
                bodyData?.append(newData)
            } else {
                bodyData = newData
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        /*request.setValue("multipart/form-data", forHTTPHeaderField: "Content-Type")
        request.setValue(postLength, forHTTPHeaderField: "Content-Length")*/
        request.allHTTPHeaderFields = headers
        request.httpBody = bodyData
        
        pendingServerResult = true
        URLSession.shared.dataTask(with: request, completionHandler: { (repData, response, err) in
            self.pendingServerResult = false
            if err == nil, let data = repData {
                if let jsonInfo = try? JSONSerialization.jsonObject(with: data, options: []) {
                    if let dict = jsonInfo as? [String: Any] {
                        print(dict)
                    }
                } else {
                    print("Couldn't read JSON: \(String(data: data, encoding: .utf8) ?? "<no description>")")
                }
            } else {
                print("Error: " + (err?.localizedDescription ?? "none"))
            }
        }).resume()
    }
    
    func matchOutputDataToCurrentObjects(_ output: [ServerResult]) {
        for result in output {
            let resultCenter = CGPoint(x: result.bounds.midX, y: result.bounds.midY)
            var closestDistance = CGFloat.greatestFiniteMagnitude
            var closestObject: TrackedObject?
            for (previouslyTrackedObject, bounds) in serverPendingLocations {
                let center = CGPoint(x: bounds.midX, y: bounds.midY)
                let dist = sqrt(pow(center.x - resultCenter.x, 2.0) + pow(center.y - resultCenter.y, 2.0))
                if dist < bounds.width * 2.0, dist < closestDistance {
                    closestObject = previouslyTrackedObject
                    closestDistance = dist
                }
            }
            if let obj = closestObject, self.trackedObjects.contains(obj) {
                obj.personName = result.name
                obj.facebookID = result.facebookID
            } else {
                let newTrackingObject = TrackedObject(bounds: result.bounds)
                newTrackingObject.personName = result.name
                newTrackingObject.facebookID = result.facebookID
                self.trackedObjects.append(newTrackingObject)
                self.addLayer(for: newTrackingObject)
            }
        }
    }
    
    func update(object: TrackedObject, with name: String) {
        object.personName = name
        updateNameLabel(for: object)
    }
    
    // MARK: - Showing Facebook Profile
    
    @objc func detectedFaceTapped(_ sender: UITapGestureRecognizer) {
        guard let trackingObject = (sender.view as? TrackingObjectView)?.trackedObject,
            let fbID = trackingObject.facebookID else {
                return
        }
        let url = URL(string: "https://www.facebook.com/profile.php?id=\(fbID)")
        guard let webVC = storyboard?.instantiateViewController(withIdentifier: "WebViewController") as? WebViewController else {
            return
        }
        webVC.url = url
        navigationController?.pushViewController(webVC, animated: true)
    }
}

