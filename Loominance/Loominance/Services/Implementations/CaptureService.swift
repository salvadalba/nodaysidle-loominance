//
//  CaptureService.swift
//  Loominance
//
//  Screen capture service using ScreenCaptureKit
//

import AVFoundation
import Combine
import CoreGraphics
import CoreVideo
import Foundation
import ScreenCaptureKit

// MARK: - Capture Session Implementation

final class DefaultCaptureSession: CaptureSessionProtocol {
    let sessionId: UUID
    let displayId: CGDirectDisplayID
    let frameRate: Int32
    let captureRect: CGRect

    private(set) var isActive: Bool = false

    private let frameSubject = PassthroughSubject<CapturedFrame, Never>()
    var framePublisher: AnyPublisher<CapturedFrame, Never> {
        frameSubject.eraseToAnyPublisher()
    }

    private var stream: SCStream?
    private var streamOutput: CaptureStreamOutput?
    private var frameNumber: Int = 0

    init(
        sessionId: UUID,
        displayId: CGDirectDisplayID,
        frameRate: Int32,
        captureRect: CGRect
    ) {
        self.sessionId = sessionId
        self.displayId = displayId
        self.frameRate = frameRate
        self.captureRect = captureRect
    }

    func start(with stream: SCStream, output: CaptureStreamOutput) {
        self.stream = stream
        self.streamOutput = output
        self.isActive = true
        self.frameNumber = 0

        // Subscribe to stream output frames
        output.frameHandler = { [weak self] pixelBuffer, timestamp, cursorPosition in
            guard let self = self else { return }

            let frame = CapturedFrame(
                pixelBuffer: pixelBuffer,
                timestamp: timestamp,
                frameNumber: self.frameNumber,
                cursorPosition: cursorPosition
            )

            self.frameNumber += 1
            self.frameSubject.send(frame)
        }
    }

    func stop() {
        isActive = false
        stream?.stopCapture { error in
            if let error = error {
                AppLogger.capture.error("Error stopping capture: \(error.localizedDescription)")
            }
        }
        stream = nil
        streamOutput = nil
    }
}

// MARK: - Stream Output Delegate

final class CaptureStreamOutput: NSObject, SCStreamOutput {

    var frameHandler: ((CVPixelBuffer, TimeInterval, CGPoint) -> Void)?
    private var startTime: TimeInterval?

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen else { return }
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestamp: TimeInterval

        if let start = startTime {
            timestamp = presentationTime.seconds - start
        } else {
            startTime = presentationTime.seconds
            timestamp = 0
            print("📸 First capture frame received!")
        }

        // Get cursor position from system
        let cursorPosition = NSEvent.mouseLocation

        // Record frame timing
        let frameStart = CFAbsoluteTimeGetCurrent()
        frameHandler?(pixelBuffer, timestamp, cursorPosition)
        let frameEnd = CFAbsoluteTimeGetCurrent()
        PerformanceMetrics.shared.recordFrameProcessingTime(frameEnd - frameStart)
    }
}

// MARK: - Capture Service Implementation

final class CaptureService: CaptureServiceProtocol {

    private(set) var currentSession: CaptureSessionProtocol?

    private let stateSubject = CurrentValueSubject<CaptureState, Never>(.idle)
    var statePublisher: AnyPublisher<CaptureState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    private var availableContent: SCShareableContent?
    private var cancellables = Set<AnyCancellable>()

    init() {
        refreshAvailableContent()
    }

    // MARK: - Public Methods

    func startCapture(
        displayId: CGDirectDisplayID,
        frameRate: Int32,
        captureRect: CGRect
    ) -> AnyPublisher<CaptureSessionProtocol, CaptureError> {

        return Future<CaptureSessionProtocol, CaptureError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.captureAlreadyActive))
                return
            }

            // Check if already capturing
            guard self.currentSession == nil else {
                promise(.failure(.captureAlreadyActive))
                return
            }

            self.stateSubject.send(.starting)

            Task {
                do {
                    // Get available content
                    let content = try await SCShareableContent.excludingDesktopWindows(
                        false, onScreenWindowsOnly: true)

                    // Find the display
                    guard
                        let display = content.displays.first(where: {
                            $0.displayID == displayId
                        })
                    else {
                        await MainActor.run {
                            self.stateSubject.send(.error("Display not found"))
                        }
                        promise(.failure(.displayNotFound(displayId: UUID())))
                        return
                    }

                    // Create content filter
                    let filter = SCContentFilter(display: display, excludingWindows: [])

                    // Create stream configuration
                    let config = SCStreamConfiguration()
                    config.width = Int(captureRect.width)
                    config.height = Int(captureRect.height)
                    config.minimumFrameInterval = CMTime(
                        value: 1, timescale: CMTimeScale(frameRate)
                    )
                    config.showsCursor = true
                    config.pixelFormat = kCVPixelFormatType_32BGRA

                    // Create stream
                    let stream = SCStream(filter: filter, configuration: config, delegate: nil)

                    // Create output handler
                    let output = CaptureStreamOutput()

                    // Add output to stream
                    try stream.addStreamOutput(
                        output, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))

                    // Start capture
                    try await stream.startCapture()

                    // Create session
                    let session = DefaultCaptureSession(
                        sessionId: UUID(),
                        displayId: displayId,
                        frameRate: frameRate,
                        captureRect: captureRect
                    )
                    session.start(with: stream, output: output)

                    await MainActor.run {
                        self.currentSession = session
                        self.stateSubject.send(.capturing)
                    }

                    AppLogger.capture.info("Capture started for display \(displayId)")
                    promise(.success(session))

                } catch {
                    await MainActor.run {
                        self.stateSubject.send(.error(error.localizedDescription))
                    }
                    AppLogger.capture.error(
                        "Failed to start capture: \(error.localizedDescription)")
                    promise(
                        .failure(.displayStreamCreationFailed(reason: error.localizedDescription)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func stopCapture() -> AnyPublisher<Void, CaptureError> {
        return Future<Void, CaptureError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.noActiveCapture))
                return
            }

            guard let session = self.currentSession as? DefaultCaptureSession else {
                promise(.failure(.noActiveCapture))
                return
            }

            self.stateSubject.send(.stopping)
            session.stop()
            self.currentSession = nil
            self.stateSubject.send(.idle)

            AppLogger.capture.info("Capture stopped")
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }

    func availableDisplays() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)

        return displays
    }

    func displayInfo(for displayId: CGDirectDisplayID) -> DisplayInfo? {
        let bounds = CGDisplayBounds(displayId)
        let isMain = CGDisplayIsMain(displayId) != 0
        let isOnline = CGDisplayIsOnline(displayId) != 0

        let name: String
        if isMain {
            name = "Main Display"
        } else {
            name = "Display \(displayId)"
        }

        return DisplayInfo(
            displayId: displayId,
            name: name,
            bounds: bounds,
            isMain: isMain,
            isOnline: isOnline
        )
    }

    // MARK: - Private Methods

    private func refreshAvailableContent() {
        Task {
            do {
                availableContent = try await SCShareableContent.excludingDesktopWindows(
                    false, onScreenWindowsOnly: true)
                AppLogger.capture.debug(
                    "Refreshed available content: \(self.availableContent?.displays.count ?? 0) displays"
                )
            } catch {
                AppLogger.capture.error(
                    "Failed to get shareable content: \(error.localizedDescription)")
            }
        }
    }
}
