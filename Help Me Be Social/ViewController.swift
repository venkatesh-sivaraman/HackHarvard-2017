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
    var frameInterval = 5
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [String : Any]?)
        frameIndex = (frameIndex + 1) % frameInterval
        if frameIndex == 0 {
            getHighAccuracyFeatures(from: ciImage)
        }
        
        updateWithLowAccuracyFeatures(from: ciImage)
    }
    
    func updateWithLowAccuracyFeatures(from image: CIImage) {
        let options: [String : Any] = [CIDetectorImageOrientation: self.exifOrientation(orientation: UIDevice.current.orientation)]
        guard let features = self.lowAccuracyDetector?.features(in: image, options: options) else {
            print("Couldn't get features")
            return
        }
        self.update(with: features.flatMap({ $0 as? CIFaceFeature }))
    }
    
    func getHighAccuracyFeatures(from image: CIImage) {
        highAccuracyQueue.async {
            let options: [String : Any] = [CIDetectorImageOrientation: self.exifOrientation(orientation: UIDevice.current.orientation)]
            guard let features = self.highAccuracyDetector?.features(in: image, options: options) else {
                print("Couldn't get high-accuracy features")
                return
            }
            print("Detected \(features.count) faces in high accuracy")
            // Grab the frames for each face
            /*for face in currentFaces {
             let croppedImage = ciImage.cropped(to: face.feature.bounds)
             }*/
        }
    }
    
    // MARK: - Handling Faces
    
    var displayedFaceLayers: [DetectedFace: FaceOverlayView] = [:]
    var currentFaces: [DetectedFace] = []
    
    func maximumCenterDelta(forFaceWithBounds bounds: CGRect) -> CGPoint {
        return CGPoint(x: bounds.size.width * 0.7, y: bounds.size.height * 0.7)
    }
    
    func update(with faces: [CIFaceFeature]) {
        // Match the new faces with the old ones
        var unmatchedFaces = [DetectedFace](currentFaces)
        for face in faces {
            var bestMatch: DetectedFace?
            var bestMatchIndex: Int = -1
            var bestMatchDelta: CGPoint = CGPoint(x: CGFloat.greatestFiniteMagnitude, y: CGFloat.greatestFiniteMagnitude)
            let maxDelta = maximumCenterDelta(forFaceWithBounds: face.bounds)
            // Find closest face that is within maxDelta of the current face
            for (i, oldFace) in unmatchedFaces.enumerated() {
                let delta = CGPoint(x: abs(oldFace.feature.bounds.midX - face.bounds.midX),
                                    y: abs(oldFace.feature.bounds.midY - face.bounds.midY))
                if delta.x < maxDelta.x, delta.y < maxDelta.y,
                    delta.x < bestMatchDelta.x, delta.y < bestMatchDelta.y {
                    bestMatch = oldFace
                    bestMatchIndex = i
                    bestMatchDelta = delta
                }
            }
            
            if let match = bestMatch {
                match.feature = face
                DispatchQueue.main.async {
                    self.updateLayer(for: match)
                }
                unmatchedFaces.remove(at: bestMatchIndex)
            } else {
                let newFace = DetectedFace(feature: face)
                currentFaces.append(newFace)
                DispatchQueue.main.async {
                    self.addLayer(for: newFace)
                }
            }
        }
        
        // Remove layers for faces that no longer have a match
        for unmatched in unmatchedFaces {
            DispatchQueue.main.async {
                self.removeLayer(for: unmatched)
            }
            if let index = currentFaces.index(of: unmatched) {
                currentFaces.remove(at: index)
            }
        }
    }
    
    // MARK: Highlighting Faces
    
    func updateLayer(for face: DetectedFace, animated: Bool = true) {
        guard let layer = displayedFaceLayers[face] else {
            print("No layer for yo face!")
            return
        }
        guard let metadataBounds = outputObject?.metadataOutputRectConverted(fromOutputRect: face.feature.bounds),
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
        if !animated {
            layer.frame = convertedBounds
        } else {
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .beginFromCurrentState, animations: {
                layer.frame = convertedBounds
            }, completion: nil)
        }
    }
    
    func addLayer(for face: DetectedFace) {
        let layer = FaceOverlayView(frame: CGRect.zero)
        view.addSubview(layer)
        displayedFaceLayers[face] = layer
        updateLayer(for: face, animated: false)
    }
    
    func removeLayer(for face: DetectedFace) {
        guard let layer = displayedFaceLayers[face] else {
            return
        }
        layer.removeFromSuperview()
        displayedFaceLayers[face] = nil
    }
}

