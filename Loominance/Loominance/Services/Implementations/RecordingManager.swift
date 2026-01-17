//
//  RecordingManager.swift
//  Loominance
//
//  Coordinates all services during recording
//

import AVFoundation
import Combine
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation

/// Recording state machine
enum RecordingState: Equatable {
    case idle
    case preparing
    case recording
    case paused
    case stopping
    case error(String)
}

/// Recording session model
struct RecordingSession: Identifiable, Equatable {
    let id: UUID
    let startTime: Date
    var duration: TimeInterval
    var frameCount: Int
    var focusZones: [FocusZoneEvent]
    var displayId: CGDirectDisplayID
    var resolution: CGSize
    var frameRate: Int32

    init(
        id: UUID = UUID(),
        displayId: CGDirectDisplayID,
        resolution: CGSize,
        frameRate: Int32
    ) {
        self.id = id
        self.startTime = Date()
        self.duration = 0
        self.frameCount = 0
        self.focusZones = []
        self.displayId = displayId
        self.resolution = resolution
        self.frameRate = frameRate
    }
}

/// Protocol for recording coordination
protocol RecordingManagerProtocol: AnyObject {
    var state: RecordingState { get }
    var statePublisher: AnyPublisher<RecordingState, Never> { get }
    var currentSession: RecordingSession? { get }

    func startRecording(displayId: CGDirectDisplayID, captureRect: CGRect)
        -> AnyPublisher<Void, CaptureError>
    func stopRecording() -> AnyPublisher<URL, CaptureError>
    func pauseRecording()
    func resumeRecording()
}

/// Coordinates all services during recording
final class RecordingManager: RecordingManagerProtocol, ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var currentSession: RecordingSession?

    var statePublisher: AnyPublisher<RecordingState, Never> {
        $state.eraseToAnyPublisher()
    }

    // MARK: - Services

    private let captureService: CaptureService
    private let predictionService: PredictionService
    private let cinematicEngine: CinematicEngine
    private let videoEncoder: VideoEncoder

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var frameSubscription: AnyCancellable?
    private var outputURL: URL?

    // Cinematic effects toggle
    var cinematicEnabled: Bool = false

    // Circuit breaker state
    private var consecutiveFailures = 0
    private let maxConsecutiveFailures = 5
    private var circuitBreakerOpen = false

    // Frame timing
    private var lastFrameTime: TimeInterval = 0
    private var lastCursorState: CursorState?
    private var frameStartTime: CMTime?

    // MARK: - Initialization

    init(
        captureService: CaptureService = CaptureService(),
        predictionService: PredictionService = PredictionService(),
        cinematicEngine: CinematicEngine = CinematicEngine(),
        videoEncoder: VideoEncoder = VideoEncoder()
    ) {
        self.captureService = captureService
        self.predictionService = predictionService
        self.cinematicEngine = cinematicEngine
        self.videoEncoder = videoEncoder

        setupServiceObservers()
    }

    // MARK: - Public Methods

    func startRecording(displayId: CGDirectDisplayID, captureRect: CGRect) -> AnyPublisher<
        Void, CaptureError
    > {
        guard state == .idle else {
            return Fail(error: CaptureError.captureAlreadyActive).eraseToAnyPublisher()
        }

        guard !circuitBreakerOpen else {
            return Fail(
                error: CaptureError.invalidConfiguration(reason: "Too many recent failures")
            ).eraseToAnyPublisher()
        }

        state = .preparing
        AppLogger.recording.info("Starting recording for display \(displayId)")

        // Generate output URL
        let outputURL = generateOutputURL()
        self.outputURL = outputURL

        // Prepare cinematic engine
        cinematicEngine.prepareBufferPool(
            width: Int(captureRect.width),
            height: Int(captureRect.height),
            bufferCount: 5
        )

        // Prepare video encoder
        let encoderConfig = VideoEncoderConfiguration.default(
            width: Int(captureRect.width),
            height: Int(captureRect.height),
            outputURL: outputURL
        )

        // Start encoder first, then capture
        return videoEncoder.startEncoding(configuration: encoderConfig)
            .mapError { _ in CaptureError.invalidConfiguration(reason: "Failed to start encoder") }
            .flatMap { [weak self] _ -> AnyPublisher<Void, CaptureError> in
                guard let self = self else {
                    return Fail(error: CaptureError.noActiveCapture).eraseToAnyPublisher()
                }

                // Load prediction model
                return self.predictionService.loadModel()
                    .mapError { _ in
                        CaptureError.invalidConfiguration(reason: "Failed to load ML model")
                    }
                    .eraseToAnyPublisher()
            }
            .flatMap { [weak self] _ -> AnyPublisher<CaptureSessionProtocol, CaptureError> in
                guard let self = self else {
                    return Fail(error: CaptureError.noActiveCapture).eraseToAnyPublisher()
                }

                // Start capture
                return self.captureService.startCapture(
                    displayId: displayId,
                    frameRate: 60,
                    captureRect: captureRect
                )
            }
            .handleEvents(receiveOutput: { [weak self] session in
                guard let self = self else { return }

                // Create recording session
                self.currentSession = RecordingSession(
                    displayId: displayId,
                    resolution: CGSize(width: captureRect.width, height: captureRect.height),
                    frameRate: 60
                )

                // Subscribe to frames
                self.subscribeToFrames(session: session)

                // Update state
                self.state = .recording
                self.consecutiveFailures = 0
                self.frameStartTime = nil

                AppLogger.recording.info("Recording started successfully")
            })
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func stopRecording() -> AnyPublisher<URL, CaptureError> {
        guard state == .recording || state == .paused else {
            return Fail(error: CaptureError.noActiveCapture).eraseToAnyPublisher()
        }

        state = .stopping
        AppLogger.recording.info("Stopping recording")

        // Unsubscribe from frames
        frameSubscription?.cancel()
        frameSubscription = nil

        // Stop capture first
        return captureService.stopCapture()
            .flatMap { [weak self] _ -> AnyPublisher<URL, CaptureError> in
                guard let self = self else {
                    return Fail(error: CaptureError.noActiveCapture).eraseToAnyPublisher()
                }

                // Finish encoding
                return self.videoEncoder.finishEncoding()
                    .mapError { error in
                        CaptureError.invalidConfiguration(reason: error.localizedDescription)
                    }
                    .eraseToAnyPublisher()
            }
            .handleEvents(
                receiveOutput: { [weak self] url in
                    // Update session duration
                    if var session = self?.currentSession {
                        session.duration = Date().timeIntervalSince(session.startTime)
                        session.frameCount = self?.videoEncoder.frameCount ?? 0
                        self?.currentSession = session
                    }

                    // Release resources
                    self?.cinematicEngine.releaseBufferPool()
                    self?.state = .idle

                    AppLogger.recording.info(
                        "Recording stopped, saved to: \(url.lastPathComponent)")
                },
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.state = .error(error.localizedDescription)
                    }
                }
            )
            .eraseToAnyPublisher()
    }

    func pauseRecording() {
        guard state == .recording else { return }
        state = .paused
        AppLogger.recording.info("Recording paused")
    }

    func resumeRecording() {
        guard state == .paused else { return }
        state = .recording
        AppLogger.recording.info("Recording resumed")
    }

    // MARK: - Private Methods

    private func setupServiceObservers() {
        // Monitor capture state
        captureService.statePublisher
            .sink { [weak self] captureState in
                self?.handleCaptureStateChange(captureState)
            }
            .store(in: &cancellables)
    }

    private func handleCaptureStateChange(_ captureState: CaptureState) {
        switch captureState {
        case .error(let message):
            handleError(message)
        default:
            break
        }
    }

    private func subscribeToFrames(session: CaptureSessionProtocol) {
        frameSubscription = session.framePublisher
            .receive(on: DispatchQueue.global(qos: .userInteractive))
            .sink { [weak self] frame in
                self?.processFrame(frame)
            }
    }

    private func processFrame(_ frame: CapturedFrame) {
        guard state == .recording else { return }

        let signpostId = PerformanceSignpost.frameCapture.makeSignpostID()
        let signpostState = PerformanceSignpost.frameCapture.beginInterval(
            "ProcessFrame", id: signpostId)

        // Calculate presentation time
        let presentationTime: CMTime
        if let startTime = frameStartTime {
            let elapsed = frame.timestamp
            presentationTime = CMTimeAdd(
                startTime, CMTimeMakeWithSeconds(elapsed, preferredTimescale: 600))
        } else {
            frameStartTime = CMTime(seconds: frame.timestamp, preferredTimescale: 600)
            presentationTime = frameStartTime!
            print("🎥 First frame received at \(frame.timestamp)")
        }

        // Debug: Print every 60 frames (1 second at 60fps)
        if frame.frameNumber % 60 == 0 {
            print("📹 Frame \(frame.frameNumber), encoder frameCount: \(videoEncoder.frameCount)")
        }

        // Update cursor history for ML prediction
        let cursorState = CursorState(
            position: frame.cursorPosition,
            timestamp: frame.timestamp,
            velocity: calculateVelocity(from: frame)
        )
        predictionService.updateCursorHistory(cursorState)
        lastCursorState = cursorState

        // Determine which buffer to encode
        var bufferToEncode = frame.pixelBuffer

        // Apply cinematic effects if enabled
        if cinematicEnabled {
            // Run ML prediction every 5 frames (12 times per second at 60fps)
            if frame.frameNumber % 5 == 0 {
                predictionService.predictFocusZone(
                    currentFrame: frame.pixelBuffer,
                    cursorPosition: frame.cursorPosition,
                    history: []  // Service maintains its own history
                )
                .receive(on: DispatchQueue.main)
                .sink { _ in
                } receiveValue: { [weak self] prediction in
                    guard let self = self else { return }
                    // Update cinematic engine with predicted focus zone
                    self.cinematicEngine.setTargetFocusZone(
                        prediction.zone,
                        transitionType: prediction.transitionType
                    )
                    self.cinematicEngine.setZoomIntensity(prediction.suggestedZoomLevel)
                }
                .store(in: &cancellables)
            }

            // Apply zoom effect with current engine state
            let result = cinematicEngine.applyZoomEffect(
                frame: frame.pixelBuffer,
                focusZone: cinematicEngine.currentFocusZone,
                intensity: cinematicEngine.currentZoomLevel
            )

            if case .success(let transformResult) = result {
                bufferToEncode = transformResult.pixelBuffer
            }
        }

        // Encode the frame
        videoEncoder.encodeFrame(bufferToEncode, presentationTime: presentationTime)

        // Update session frame count
        DispatchQueue.main.async { [weak self] in
            self?.currentSession?.frameCount = self?.videoEncoder.frameCount ?? 0
            self?.currentSession?.duration = frame.timestamp
        }

        PerformanceSignpost.frameCapture.endInterval("ProcessFrame", signpostState)
    }

    private func calculateVelocity(from frame: CapturedFrame) -> CGVector {
        guard let last = lastCursorState else {
            return .zero
        }
        let dt = frame.timestamp - last.timestamp
        guard dt > 0 else { return .zero }

        let dx = (frame.cursorPosition.x - last.position.x) / dt
        let dy = (frame.cursorPosition.y - last.position.y) / dt
        return CGVector(dx: dx, dy: dy)
    }

    private func handleError(_ message: String) {
        state = .error(message)
        consecutiveFailures += 1
        AppLogger.recording.error("Recording error: \(message)")
    }

    private func generateOutputURL() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        let fileName = "Loominance_\(timestamp).mp4"

        let documentsURL = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let recordingsURL = documentsURL.appendingPathComponent("Loominance/Recordings")

        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: recordingsURL, withIntermediateDirectories: true)

        return recordingsURL.appendingPathComponent(fileName)
    }
}
