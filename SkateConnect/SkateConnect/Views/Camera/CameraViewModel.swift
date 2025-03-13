//
//  CameraViewModel.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/26/24.
//

import os

import AVFoundation
import SwiftUI

class CameraViewModel: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    let log = OSLog(subsystem: "SkateConnect", category: "Camera")

    @Published var isRecording = false
    @Published var isVideoRecorded = false
    @Published var showingPreview = false
    @Published var showZoomHint = true
    @Published var hasCameraAccess = true
    @Published var cameraReady = false

    // Zoom factors for different camera modes
    var zoomFactor: CGFloat = 1.0 // Current zoom factor
    var wideAngleZoomFactor: CGFloat = 1.0 // Last zoom factor for wide-angle mode
    var standardZoomFactor: CGFloat = 1.0 // Last zoom factor for standard mode

    private var currentDevice: AVCaptureDevice?
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureMovieFileOutput()

    // Dedicated queue for camera operations
    private let sessionQueue = DispatchQueue(label: "ninja.skate.sessionQueue", qos: .userInitiated)
    
    // Track if observers have been registered
    private var observersRegistered = false

    override init() {
        super.init()
        
        registerObservers()
    }
    
    // Register notification observers
    private func registerObservers() {
        guard !observersRegistered else { return }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionRuntimeError),
                                               name: .AVCaptureSessionRuntimeError,
                                               object: session)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionWasInterrupted),
                                               name: .AVCaptureSessionWasInterrupted,
                                               object: session)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionInterruptionEnded),
                                               name: .AVCaptureSessionInterruptionEnded,
                                               object: session)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionDidStartRunning),
                                               name: .AVCaptureSessionDidStartRunning,
                                               object: session)
        
        observersRegistered = true
    }
    
    // Unregister notification observers
    private func unregisterObservers() {
        guard observersRegistered else { return }
        
        NotificationCenter.default.removeObserver(self,
                                                 name: .AVCaptureSessionRuntimeError,
                                                 object: session)
        
        NotificationCenter.default.removeObserver(self,
                                                 name: .AVCaptureSessionWasInterrupted,
                                                 object: session)
        
        NotificationCenter.default.removeObserver(self,
                                                 name: .AVCaptureSessionInterruptionEnded,
                                                 object: session)
        
        NotificationCenter.default.removeObserver(self,
                                                 name: .AVCaptureSessionDidStartRunning,
                                                 object: session)
        
        observersRegistered = false
    }
    
//    deinit {
//        stopSession()
//    }
    
    func stopSession(completion: (() -> Void)? = nil) {
        if isRecording {
            stopRecording()
        }
        
        DispatchQueue.main.async {
            self.unregisterObservers()
            self.cameraReady = false
            
            self.sessionQueue.async {
                if self.session.isRunning {
                    self.session.stopRunning()
                    os_log("⏳ Camera session stopped", log: self.log, type: .info)
                }
                
                DispatchQueue.main.async {
                    completion?()
                }
            }
        }
    }
    
    @objc func sessionDidStartRunning(notification: NSNotification) {
        DispatchQueue.main.async {
            self.cameraReady = true
            os_log("⏳ Camera session started running successfully", log: self.log, type: .info)
            
            os_log("🔍 session.isRunning: %d", log: self.log, type: .info, self.session.isRunning ? 1 : 0)
            os_log("🔍 inputs: %@", log: self.log, type: .info, self.session.inputs)
            os_log("🔍 outputs %@:", log: self.log, type: .info, self.session.outputs)
        }
    }
    
    @objc func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        os_log("⏳ Capture session runtime error: %@", log: self.log, type: .info, error.localizedDescription)

        
        
        // Try to restart the session
        sessionQueue.async {
            // Stop the current session
            self.session.stopRunning()
            
            DispatchQueue.main.async {
                self.cameraReady = false
            }
            
            // Wait a moment before restarting
            Thread.sleep(forTimeInterval: 0.5)
            
            // Start the session again
            self.session.startRunning()
        }
    }
    
    @objc func sessionWasInterrupted(notification: NSNotification) {
        DispatchQueue.main.async {
            self.cameraReady = false
            os_log("🔥 Session was interrupted", log: self.log, type: .info)

        }
    }
    
    @objc func sessionInterruptionEnded(notification: NSNotification) {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    // MARK: - Check Permissions and Setup
    func checkPermissionsAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraAccess = true
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.hasCameraAccess = granted
                    if granted {
                        self.configureSession()
                    } else {
                        os_log("⏳ Camera access denied.", log: self.log, type: .info)
                    }
                }
            }
        case .denied, .restricted:
            hasCameraAccess = false
            os_log("⏳ Camera access denied or restricted.", log: self.log, type: .info)

        @unknown default:
            hasCameraAccess = false
            os_log("⏳ Unknown camera permission status.", log: self.log, type: .info)
        }
    }

    // MARK: - Configure Camera Session
    func configureSession() {
        // Ensure observers are registered
        if !observersRegistered {
            registerObservers()
        }
        
        // Wait before reconfiguring if already running
        if session.isRunning {
            sessionQueue.async {
                os_log("⏳ stopping previous session", log: self.log, type: .info)
                self.session.stopRunning()
                Thread.sleep(forTimeInterval: 0.5)
                self.setupCameraSession()
            }
        } else {
            sessionQueue.async {
                self.setupCameraSession()
            }
        }
    }
    
    private func setupCameraSession() {
        os_log("⏳ setting up camera session", log: self.log, type: .info)

        // Set the sessionPreset before configuration
        self.session.sessionPreset = .high
        
        self.session.beginConfiguration()
        
        // Remove any existing inputs and outputs
        for input in self.session.inputs {
            self.session.removeInput(input)
        }
        
        for output in self.session.outputs {
            self.session.removeOutput(output)
        }

        // Check if the camera is available
        guard let videoDevice = self.getBestCamera() else {
            os_log("⏳ Camera is not available or disabled.", log: self.log, type: .info)

            DispatchQueue.main.async {
                self.hasCameraAccess = false
            }
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if self.session.canAddInput(videoInput) {
                self.session.addInput(videoInput)
                self.currentDevice = videoDevice
            } else {
                os_log("🛑 Could not add video input", log: self.log, type: .info)
                DispatchQueue.main.async {
                    self.hasCameraAccess = false
                }
                return
            }
        } catch {
            os_log("🔥 Error: Unable to add video input: %@", log: self.log, type: .info, error.localizedDescription)
            DispatchQueue.main.async {
                self.hasCameraAccess = false
            }
            return
        }

        // Add audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if self.session.canAddInput(audioInput) {
                    self.session.addInput(audioInput)
                }
            } catch {
                os_log("🔥 Error: Unable to add audio input: %@", log: self.log, type: .info, error.localizedDescription)
            }
        }

        // Add video output
        if self.session.canAddOutput(self.videoOutput) {
            self.session.addOutput(self.videoOutput)
            
            if let connection = self.videoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90  // Portrait mode
                }

                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
        }

        self.session.commitConfiguration()

        // Start the session
        if !self.session.isRunning {
            os_log("⏳ Starting camera session...", log: log, type: .info)

            self.session.startRunning()
        }
    }
    
    // Function to get the best available camera
    private func getBestCamera() -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return device
        }
        
        // Fallback to any available camera
        return AVCaptureDevice.default(for: .video)
    }

    // MARK: - Start Recording
    func startRecording() {
        guard session.isRunning, cameraReady else {
            os_log("🛑 Cannot start recording - camera not ready", log: self.log, type: .info)
            return
        }
        
        let outputDirectory = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".mov"
        let url = outputDirectory.appendingPathComponent(fileName)

        sessionQueue.async {
            self.videoOutput.startRecording(to: url, recordingDelegate: self)
            DispatchQueue.main.async {
                self.isRecording = true
            }
        }
    }

    // MARK: - Stop Recording
    func stopRecording() {
        guard isRecording else { return }
        
        sessionQueue.async {
            if self.videoOutput.isRecording {
                self.videoOutput.stopRecording()
            }
            DispatchQueue.main.async {
                self.isRecording = false
            }
        }
    }

    // MARK: - Delegate Method for Saving File
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            os_log("🔥 Recording error: %@", log: self.log, type: .info, error.localizedDescription)
            return
        }

        DispatchQueue.main.async {
            self.isVideoRecorded = true
        }
        
        NotificationCenter.default.post(
            name: .didFinishRecordingTo,
            object: self,
            userInfo: ["videoURL": outputFileURL]
        )
        
        os_log("✔️ Video saved at: %@", log: log, type: .info, outputFileURL.absoluteString)
    }

    // MARK: - Zoom Functionality
    func zoom(factor: CGFloat) {
        guard let device = currentDevice ?? AVCaptureDevice.default(for: .video),
              device.activeFormat.videoMaxZoomFactor > factor else {
            return
        }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = factor
                device.unlockForConfiguration()

                // Save the zoom factor globally
                DispatchQueue.main.async {
                    self.zoomFactor = factor
                }
            } catch {
                os_log("🔥 Failed to set zoom: %@", log: self.log, type: .info, error.localizedDescription)
            }
        }
    }

    // Function to switch between wide and normal lenses and restore zoom
    func switchToWideAngle() {
        guard let wideDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Wide angle camera not available")
            return
        }

        // Store the current zoom factor for the standard camera
        standardZoomFactor = zoomFactor

        // Switch camera and restore last zoom level for wide-angle
        switchCamera(to: wideDevice)
        zoom(factor: wideAngleZoomFactor)
    }

    func switchToStandard() {
        guard let normalDevice = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) else {
            os_log("🛑 Standard telephoto camera not available", log: self.log, type: .info)
            return
        }

        // Store the current zoom factor for the wide-angle camera
        wideAngleZoomFactor = zoomFactor

        // Switch camera and restore last zoom level for standard camera
        switchCamera(to: normalDevice)
        zoom(factor: standardZoomFactor)
    }

    private func switchCamera(to device: AVCaptureDevice) {
        sessionQueue.async {
            self.session.beginConfiguration()

            // Remove all inputs
            self.session.inputs.forEach { self.session.removeInput($0) }

            do {
                let newInput = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.currentDevice = device
                }
            } catch {
                os_log("🔥 Failed to switch camera: %@", log: self.log, type: .info, error.localizedDescription)
            }

            self.session.commitConfiguration()
        }
    }
}
