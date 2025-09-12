//
//  LiveVideoScreen.swift
//  YEOFRSampleApp
//
//  Created by paul calver on 02/09/2025.
//

import SwiftUI
import YEOFR

struct LiveVideoScreen: View {
    @Environment(\.dismiss) var dismiss
    @State private var viewModel = ViewModel()
    @State private var showRegisteredAnimation = false

    var body: some View {
        VStack {
            ZStack {
                if let session = viewModel.videoStream.session {
                    GeometryReader { proxy in
                        VideoPreviewHolder(runningSession: session)
                            .ignoresSafeArea()
                            .frame(width: proxy.size.height * 16 / 9, height: proxy.size.height)
                            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    }

                    if let enrollmentStepState = viewModel.videoScreenState.enrollmentStepState {
                        GeometryReader { geometry in
                            VStack {
                                Spacer()
                                CircularProgressView(
                                    progress: enrollmentStepState.progress,
                                    isGood: enrollmentStepState.recognised,
                                    lineWidth: 12
                                )
                                .frame(width: geometry.size.width / 2,
                                       height: geometry.size.width / 2)
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: .infinity)
                                .position(x: geometry.size.width / 2,
                                          y: geometry.size.height / 2)
                                Spacer()
                            }
                        }
                        .ignoresSafeArea()
                    }

                    VStack {
                        textDetailsView()

                        Spacer()

                        if viewModel.videoScreenState.isRecognising {
                            Button {
                                viewModel.beginRegistration(maxSteps: 50)
                            } label: {
                                Text("Register a face multi frame")
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(.black)
                                    .cornerRadius(12)
                            }
                            .disabled(viewModel.numberOfFacesDetected != 1)
                        }

                        if viewModel.videoScreenState.isRegistered {
                            Button {
                                viewModel.deleteRegisteredFace()
                            } label: {
                                Text("Delete registered face")
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(.red)
                                    .cornerRadius(12)
                            }
                        }
                        Text("SDK Version \(YEOFRSDK.version)")
                    }

                    // Big green tick overlay
                    GreenTickAnimation(isVisible: $showRegisteredAnimation)

                } else {
                    ProgressView("Starting camera…")
                        .task { viewModel.start() }
                }
            }
        }
        // forward image frame params to the VM
        .onChange(of: viewModel.imageFrameParameters, initial: false) { _, new in
            viewModel.processImageFrameParameters(new)
        }
        .onAppear {
            viewModel.onRegistered = {
                showRegisteredAnimation = true
            }
        }
        .onDisappear {
            finishVideoStream()
        }
    }

    @ViewBuilder
    private func textDetailsView() -> some View {
        VStack {
            VStack(spacing: 16) {
                Text("Faces detected: \(viewModel.numberOfFacesDetected)")
                    .font(.headline)
                    .foregroundColor(.black)
                Text("Faces recognised: \(viewModel.numberOfFacesRecognised)")
                    .font(.headline)
                    .foregroundColor(.black)

                if let enrollmentState = viewModel.videoScreenState.enrollmentStepState {
                    Text("Enrollment step: \(enrollmentState.step)")
                        .font(.headline)
                        .foregroundColor(.black)
                    Text("Recognised: \(enrollmentState.recognised.description)")
                        .font(.headline)
                        .foregroundColor(.black)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .padding()
        }
    }
}

extension LiveVideoScreen {
    func finishVideoStream() {
        viewModel.finish()
    }
}

// MARK: viewModel
extension LiveVideoScreen {
    @MainActor
    @Observable
    final class ViewModel {
        @ObservationIgnored
        private var trackingTask: Task<Void, Never>?

        // Callback for UI side-effects (e.g., show green tick)
        var onRegistered: (() -> Void)?

        // Expose UI state from the VM
        var videoScreenState: VideoScreenState = .recognising

        var videoStream = VideoStream()
        var hasSession: Bool { videoStream.session != nil }

        // Face recognition result drives the state machine
        var currentFRResult: SDKFaceRecognitionResult? {
            didSet {
                handleFRUpdate(oldValue: oldValue, newValue: currentFRResult)
            }
        }

        var numberOfFacesDetected: Int {
            currentFRResult?.detectedCount ?? 0
        }

        var numberOfFacesRecognised: Int {
            currentFRResult?.faceIDs.values.compactMap({ $0 }).count ?? 0
        }

        // Pass-through from stream so the View can forward onChange
        var imageFrameParameters: ImageFrameParameters? {
            videoStream.currentImageFrameParameters
        }

        // MARK: - Public Intents

        func start()  { videoStream.start() }
        func finish() { videoStream.finish() }

        func beginRegistration(maxSteps: Int = 50) {
            videoScreenState = .registering(EnrollmentStepState(step: 0, maxSteps: maxSteps, recognised: false))
        }

        func deleteRegisteredFace() {
            YEOFRSDK.shared.freeTracker()
            YEOFRSDK.shared.createTracker()
            videoScreenState = .recognising
        }

        func processImageFrameParameters(_ parameters: ImageFrameParameters?) {
            guard let parameters = parameters else { return }
            currentFRResult = YEOFRSDK.shared.detectFaces(params: parameters, needFaceRect: true)
        }

        @discardableResult
        func registerFace(for faceID: Int64, name: String) -> Bool {
            YEOFRSDK.shared.enroll(faceID: faceID, name: name)
        }

        // MARK: - Private State Machine

        private func handleFRUpdate(oldValue: SDKFaceRecognitionResult?, newValue: SDKFaceRecognitionResult?) {
            guard videoScreenState.isRegistering,
                  let enrollmentStepState = videoScreenState.enrollmentStepState else { return }

            var currentStep = enrollmentStepState.step

            // Only progress if exactly 1 face detected
            guard let detectedCount = newValue?.detectedCount, detectedCount == 1 else {
                videoScreenState = .registering(EnrollmentStepState(step: currentStep,
                                                                   maxSteps: enrollmentStepState.maxSteps,
                                                                   recognised: false))
                return
            }

            // Step 0: attempt initial registration
            if currentStep == 0 {
                guard let faceId = newValue?.faceIDs.keys.first else {
                    videoScreenState = .registering(EnrollmentStepState(step: currentStep,
                                                                       maxSteps: enrollmentStepState.maxSteps,
                                                                       recognised: false))
                    return
                }

                if registerFace(for: Int64(faceId), name: "SampleAppUser") {
                    currentStep += 1
                    videoScreenState = .registering(EnrollmentStepState(step: currentStep,
                                                                       maxSteps: enrollmentStepState.maxSteps,
                                                                       recognised: true))
                }
                return
            }

            // Done?
            guard currentStep < enrollmentStepState.maxSteps else {
                videoScreenState = .registered
                // Fire UI hook
                onRegistered?()
                return
            }

            // Progress one step only if exactly 1 non-nil recognised ID
            var recognised = false
            if let countNonNil = newValue?.faceIDs.compactMapValues({ $0 }).count, countNonNil == 1 {
                currentStep += 1
                recognised = true
            }

            videoScreenState = .registering(EnrollmentStepState(step: currentStep,
                                                               maxSteps: enrollmentStepState.maxSteps,
                                                               recognised: recognised))
        }
    }
}
