//
//  CameraView.swift
//  studio-plus
//
//  Created by Lindsay Pond on 3/25/17.
//  Copyright © 2017 Lindsay Angela Ena. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

protocol CameraViewDelegate {
    func showPhoto(image: UIImage)
    func toggleHint()
    func backToMap()
}

class CameraView: UIView {
    var delegate: CameraViewDelegate?
    @IBOutlet weak var camPreview: UIView!
    @IBOutlet weak var thumbnail: UIButton!
    @IBOutlet weak var hintButton: UIButton!
    
    @IBOutlet var hintImage: UIImageView!
    @IBOutlet weak var switchCameraButton: UIButton!
    
    //MARK - Properties
    var catEars: UIImageView?
    let captureSession = AVCaptureSession()
    let imageOutput = AVCaptureStillImageOutput()
    var previewLayer: AVCaptureVideoPreviewLayer!
    var activeInput: AVCaptureDeviceInput!
    
    var brandImageDefault: UIImage?
    var brandImageSelected: UIImage?
    
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "Camera", bundle: nil).instantiate(withOwner: nil, options: nil)[0] as! UIView
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @IBAction func switchCameras(_ sender: AnyObject) {
        // Make sure the device has more than 1 camera.
        if AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo).count > 1 {
            // Check which position the active camera is.
            var newPosition: AVCaptureDevicePosition!
            if activeInput.device.position == AVCaptureDevicePosition.back {
                newPosition = AVCaptureDevicePosition.front
            } else {
                newPosition = AVCaptureDevicePosition.back
            }
            
            // Get camera at new position.
            var newCamera: AVCaptureDevice!
            let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
            for device in devices! {
                if (device as AnyObject).position == newPosition {
                    newCamera = device as! AVCaptureDevice
                }
            }
            
            // Create new input and update capture session.
            do {
                let input = try AVCaptureDeviceInput(device: newCamera)
                captureSession.beginConfiguration()
                // Remove input for active camera.
                captureSession.removeInput(activeInput)
                // Add input for new camera.
                if captureSession.canAddInput(input) == true {
                    captureSession.addInput(input)
                    activeInput = input
                } else {
                    captureSession.addInput(activeInput)
                }
                captureSession.commitConfiguration()
            } catch {
                print("Error switching cameras: \(error)")
            }
        }
    }
    
    func toggleHint(toSelected: Bool? = nil) {
        let isSelected = toSelected ?? !hintButton.isSelected
        hintButton.isSelected = isSelected
        hintImage.image = isSelected ? brandImageSelected : brandImageDefault
    }


    @IBAction func toggleHint(_ sender: UIButton) {
        toggleHint()
        delegate?.toggleHint()
        
    }
    
    func drawCatEars(image: UIImage) -> UIImage? {
        let catEarsImage = UIImage(named: "catears")
        let width = (catEars!.frame.size.width / self.frame.size.width) * image.size.width
        let height = (catEars!.frame.size.height / self.frame.size.height) * image.size.height
        let size = CGSize (width: width, height: height)
        UIGraphicsBeginImageContextWithOptions(image.size, true, 0.0)
        image.draw(at: CGPoint(x: 0, y: 0))
        catEarsImage?.draw(in: CGRect(origin: catEars!.frame.origin, size: size))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return scaledImage
    }
    
    @IBAction func displayThumbnail(_ sender: Any) {
        guard let image = thumbnail.currentBackgroundImage else {
            return
        }
    
        delegate?.showPhoto(image: image)
    }
    
    @IBAction func backToMap(_ sender: Any) {
        delegate?.backToMap()
    }

    func configure(brandAssets: CameraBrandAssets) {
        if let defaultImage =  UIImage(named: brandAssets.hintImageDefaultName) {
            brandImageDefault = defaultImage
        }
        if let selectedImage =  UIImage(named: brandAssets.hintImageActivatedName) {
            brandImageSelected = selectedImage
        }
        
        
    }
    
    func currentVideoOrientation() -> AVCaptureVideoOrientation {
        var orientation: AVCaptureVideoOrientation
        
        switch UIDevice.current.orientation {
        case .portrait:
            orientation = AVCaptureVideoOrientation.portrait
        case .landscapeRight:
            orientation = AVCaptureVideoOrientation.landscapeLeft
        case .portraitUpsideDown:
            orientation = AVCaptureVideoOrientation.portraitUpsideDown
        default:
            orientation = AVCaptureVideoOrientation.landscapeRight
        }
        
        return orientation
    }
    
    func setPhotoThumbnail(_ image: UIImage) {
        DispatchQueue.main.async { () -> Void in
            self.thumbnail.contentMode = .scaleAspectFit
            
            self.thumbnail.setBackgroundImage(image, for: UIControlState())
            self.thumbnail.layer.borderColor = UIColor.white.cgColor
            self.thumbnail.layer.borderWidth = 1.0
            
        }
    }
    
    func savePhotoToLibrary(_ image: UIImage) {
        let photoLibrary = PHPhotoLibrary.shared()
        photoLibrary.performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { (success: Bool, error: Error?) -> Void in
            if success {
                // Set thumbnail
                self.setPhotoThumbnail(image)
            } else {
                print("Error writing to photo library: \(error!.localizedDescription)")
            }
        }
    }
    
    @IBAction func capturePhoto(_ sender: AnyObject) {
        let connection = imageOutput.connection(withMediaType: AVMediaTypeVideo)
        if (connection?.isVideoOrientationSupported) == true {
            connection?.videoOrientation = currentVideoOrientation()
        }
        
        imageOutput.captureStillImageAsynchronously(from: connection, completionHandler: { (sampleBuffer, error) in
            if sampleBuffer != nil {
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                
                if let image = UIImage(data: imageData!), let catImage = self.drawCatEars(image: image) {
                    self.savePhotoToLibrary(catImage)
                }
        
            } else {
                print("Error capturing photo: \(error?.localizedDescription)")
            }
        })
    }
    
    func videoQueue() -> DispatchQueue {
        return DispatchQueue.global()
    }
    
    func setupPreview() {
        // Configure previewLayer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = camPreview.bounds
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        camPreview.layer.addSublayer(previewLayer)
    }
    
    func setupSession() {
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        let camera = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                activeInput = input
            }
        } catch {
            print("Error setting device input: \(error)")
        }
        
        imageOutput.outputSettings = [AVVideoCodecKey : AVVideoCodecJPEG]
        if captureSession.canAddOutput(imageOutput) {
            captureSession.addOutput(imageOutput)
        }
        
    }
    
    func startSession() {
        if !captureSession.isRunning {
            videoQueue().async {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            videoQueue().async {
                self.captureSession.stopRunning()
            }
        }
    }
    
}
