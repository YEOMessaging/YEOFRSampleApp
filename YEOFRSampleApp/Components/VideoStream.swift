//
//  VideoStream.swift
//  YEOFRSampleApp
//
//  Created by paul calver on 02/09/2025.
//

import Foundation
import AVKit
import Vision
import SwiftData
import AVFoundation
import YEOFR
import CoreVideo
import Accelerate


@Observable
class VideoStream: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var cameraAccess = false
    
    @ObservationIgnored
        private var configured = false
    
    @ObservationIgnored
    var lastTimestamp = CMTime()
    
    public var currentImageFrameParameters: ImageFrameParameters?
    
    public var session: AVCaptureSession?
    private let configureAVCaptureSessionQueue = DispatchQueue(label: "ConfigureAVCaptureSessionQueue")
    private let captureOutputQueue = DispatchQueue(label: "CaptureOutputQueue")
    private var frameCount = 0
    private let framesToDiscard = 10
    private var videoDevice: AVCaptureDevice?
    
    private let processingGate = DispatchSemaphore(value: 1)
    private let ciContext = CIContext(options: nil)  // single shared context
    
    private let framesRequired = 8
    private var outdoorFrameCount = 0
    private var latestBuffer: CMSampleBuffer?
    
    override init() {
        super.init()
    }
    
    public func start() {
        guard !configured else {
            session?.startRunning();
            return
        }
        
        self.authorizeCapture()
    }

    public func finish() {
        session?.stopRunning()
        session = nil
        configured = false
    }
    
    private func authorizeCapture() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.cameraAccess = true }
            beginCapture()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async { self.cameraAccess = true }
                    self.beginCapture()
                }
            }
        default:
            return
        }
    }
    
    private func beginCapture() {
            if configured {
                configureAVCaptureSessionQueue.async { [weak self] in
                    guard let self, let s = self.session, !s.isRunning else { return }
                    s.startRunning()
                }
                return
            }

            // Create the session on the session queue
        configureAVCaptureSessionQueue.async { [weak self] in
                guard let self else { return }
                let s = AVCaptureSession()

                s.beginConfiguration()
                s.sessionPreset = .photo

                // Inputs
                guard
                    let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                    let input = try? AVCaptureDeviceInput(device: device),
                    s.canAddInput(input)
                else {
                    self.finishOnMain(session: nil, configured: false)
                    return
                }
                
            s.addInput(input)
            // 20fps
            do {
              try input.device.lockForConfiguration()
                input.device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 20)
                input.device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 20)
              
                input.device.unlockForConfiguration()
            } catch {
            }
                

                // Outputs
                let videoOutput = AVCaptureVideoDataOutput()
                videoOutput.setSampleBufferDelegate(self, queue: self.captureOutputQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [ String(kCVPixelBufferPixelFormatTypeKey): kCMPixelFormat_32BGRA] // IMPORTANT!! FR expects 32BGRA
            
            if s.canAddOutput(videoOutput) {
                s.addOutput(videoOutput)
                videoOutput.connection(with: .video)?.videoOrientation = .portrait
            }

                s.commitConfiguration()

                if !s.isRunning { s.startRunning() }

                // Publish to SwiftUI on main
                self.finishOnMain(session: s, configured: true)
            }
        }

    private func endCapture() {
        guard let session = self.session else { return }

        session.beginConfiguration()
        for output in session.outputs {
            if let v = output as? AVCaptureVideoDataOutput {
                v.setSampleBufferDelegate(nil, queue: nil)
            }
            session.removeOutput(output)
        }
        for input in session.inputs { session.removeInput(input) }
        session.commitConfiguration()

        if session.isRunning { session.stopRunning() }
        self.session = nil
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let buffer = sampleBuffer
        
        guard CMSampleBufferIsValid(buffer), let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return
        }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let deltaTime = timestamp - lastTimestamp
        
        if deltaTime >= CMTimeMake(value: 1, timescale: 20 ) {
            lastTimestamp = timestamp
            let capturedImage: CIImage = CIImage(cvPixelBuffer: imageBuffer)
            let imageParameters = ImageFrameParameters.imageParameter(forImageBuffer: imageBuffer)
            
            currentImageFrameParameters = imageParameters
        }
    }
}


extension VideoStream {
   // @MainActor
        private func finishOnMain(session: AVCaptureSession?, configured: Bool) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.session = session
                self.configured = configured
            }
        }
}
