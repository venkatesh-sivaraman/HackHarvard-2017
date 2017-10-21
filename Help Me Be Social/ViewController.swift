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

class ViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    @IBOutlet var liveFeedView: UIView!
    var liveFeed: AVCaptureVideoPreviewLayer?
    var cameraSession: AVCaptureSession?
    var captureDevice: AVCaptureDevice?
    var metadataOutput: AVCaptureMetadataOutput?
    
    lazy var featureDetector: CIDetector? = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])
    lazy var outputQueue: DispatchQueue = DispatchQueue(label: "helpmebesocial.camera-output")
    
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
        
        /*let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        output.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }*/
        
        let faceDetector = AVCaptureMetadataOutput()
        faceDetector.setMetadataObjectsDelegate(self, queue: outputQueue)
        
        if session.canAddOutput(faceDetector) {
            session.addOutput(faceDetector)
        }
        if faceDetector.availableMetadataObjectTypes.contains(.face) {
            faceDetector.metadataObjectTypes = [.face]
        } else {
            print(faceDetector.availableMetadataObjectTypes)
        }

        session.commitConfiguration()
        
        let feedLayer = AVCaptureVideoPreviewLayer(session: session)
        liveFeedView.layer.addSublayer(feedLayer)
        
        captureDevice = device
        liveFeed = feedLayer
        cameraSession = session
        metadataOutput = faceDetector
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
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        update(with: metadataObjects.flatMap({ $0 as? AVMetadataFaceObject }))
    }
    // MARK: - Handling Faces
    
    var displayedFaceLayers: [DetectedFace: UIView] = [:]
    var currentFaces: [DetectedFace] = []
    
    func maximumCenterDelta(forFaceWithBounds bounds: CGRect) -> CGPoint {
        return CGPoint(x: bounds.size.width * 0.3, y: bounds.size.height * 0.3)
    }
    
    func update(with faces: [AVMetadataFaceObject]) {
        // Match the new faces with the old ones
        var unmatchedFaces = [DetectedFace](currentFaces)
        for face in faces {
            var bestMatch: DetectedFace?
            var bestMatchIndex: Int = -1
            for (i, oldFace) in unmatchedFaces.enumerated() {
                if oldFace.faceID == face.faceID {
                    bestMatch = oldFace
                    bestMatchIndex = i
                }
            }
            
            if let match = bestMatch {
                match.metadataObject = face
                DispatchQueue.main.async {
                    self.updateLayer(for: match)
                }
                unmatchedFaces.remove(at: bestMatchIndex)
            } else {
                let newFace = DetectedFace(object: face)
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
    
    var highlightLayerCornerRadius = CGFloat(6.0)
    
    func updateLayer(for face: DetectedFace) {
        guard let layer = displayedFaceLayers[face] else {
            print("No layer for yo face!")
            return
        }
        guard let metadataObj = face.metadataObject,
            let transformed = liveFeed?.transformedMetadataObject(for: metadataObj) else {
            print("Couldn't transform metadata object")
            return
        }
        let convertedBounds = transformed.bounds
        layer.frame = convertedBounds.offsetBy(dx: liveFeed?.frame.origin.x ?? 0.0, dy: liveFeed?.frame.origin.y ?? 0.0)
    }
    
    func addLayer(for face: DetectedFace) {
        let layerView = FaceOverlayView(frame: CGRect.zero)
        view.addSubview(layerView)
        displayedFaceLayers[face] = layerView
        updateLayer(for: face)
    }
    
    func removeLayer(for face: DetectedFace) {
        guard let layer = displayedFaceLayers[face] else {
            return
        }
        layer.removeFromSuperview()
        displayedFaceLayers[face] = nil
    }
}

