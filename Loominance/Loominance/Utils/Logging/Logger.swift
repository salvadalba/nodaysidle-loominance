//
//  Logger.swift
//  Loominance
//
//  Centralized logging infrastructure using OSLog
//

import Foundation
import OSLog

/// Centralized logging subsystem for Loominance
/// Uses Apple's unified logging system (OSLog)
enum LogCategory: String, CaseIterable {
    case app = "App"
    case captureService = "CaptureService"
    case predictionService = "PredictionService"
    case cinematicEngine = "CinematicEngine"
    case exportService = "ExportService"
    case libraryManager = "LibraryManager"
    case pasteboardService = "PasteboardService"
    case recordingManager = "RecordingManager"
    case ui = "UI"
    case performance = "Performance"
}

/// Thread-safe logger wrapper around OSLog
final class AppLogger {

    private static let subsystem = "com.loominance.app"

    private static var loggers: [LogCategory: Logger] = {
        var result: [LogCategory: Logger] = [:]
        for category in LogCategory.allCases {
            result[category] = Logger(subsystem: subsystem, category: category.rawValue)
        }
        return result
    }()

    private init() {}

    // MARK: - Shared Category Loggers

    /// Logger for general app lifecycle events
    static let app = AppLogger.logger(for: .app)

    /// Logger for screen capture operations
    static let capture = AppLogger.logger(for: .captureService)

    /// Logger for Core ML prediction operations
    static let prediction = AppLogger.logger(for: .predictionService)

    /// Logger for cinematic zoom/pan engine
    static let cinematic = AppLogger.logger(for: .cinematicEngine)

    /// Logger for export operations
    static let export = AppLogger.logger(for: .exportService)

    /// Logger for library management
    static let library = AppLogger.logger(for: .libraryManager)

    /// Logger for pasteboard operations
    static let pasteboard = AppLogger.logger(for: .pasteboardService)

    /// Logger for recording coordination
    static let recording = AppLogger.logger(for: .recordingManager)

    /// Logger for UI events
    static let ui = AppLogger.logger(for: .ui)

    /// Logger for performance metrics
    static let performance = AppLogger.logger(for: .performance)

    // MARK: - Custom Logger Access

    /// Get logger for a specific category
    static func logger(for category: LogCategory) -> Logger {
        return loggers[category]!
    }
}

// MARK: - Signpost Infrastructure

/// Performance signpost infrastructure for Instruments profiling
enum PerformanceSignpost {

    private static let subsystem = "com.loominance.app"

    /// Signpost for frame capture timing
    static let frameCapture = OSSignposter(subsystem: subsystem, category: "FrameCapture")

    /// Signpost for ML prediction timing
    static let prediction = OSSignposter(subsystem: subsystem, category: "Prediction")

    /// Signpost for transform/zoom operations
    static let transform = OSSignposter(subsystem: subsystem, category: "Transform")

    /// Signpost for encoding operations
    static let encoding = OSSignposter(subsystem: subsystem, category: "Encoding")

    /// Signpost for recording lifecycle
    static let recording = OSSignposter(subsystem: subsystem, category: "Recording")

    /// Signpost for export operations
    static let export = OSSignposter(subsystem: subsystem, category: "Export")
}

// MARK: - Performance Metrics

/// Lightweight performance metrics collection
final class PerformanceMetrics: @unchecked Sendable {

    static let shared = PerformanceMetrics()

    private var frameProcessingTimes: [TimeInterval] = []
    private var mlInferenceTimes: [TimeInterval] = []
    private var framesDropped: Int = 0

    private let lock = NSLock()
    private let maxSamples = 1000

    private init() {}

    /// Record frame processing time
    func recordFrameProcessingTime(_ time: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }

        frameProcessingTimes.append(time)
        if frameProcessingTimes.count > maxSamples {
            frameProcessingTimes.removeFirst()
        }
    }

    /// Record ML inference time
    func recordMLInferenceTime(_ time: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }

        mlInferenceTimes.append(time)
        if mlInferenceTimes.count > maxSamples {
            mlInferenceTimes.removeFirst()
        }
    }

    /// Increment dropped frame counter
    func recordDroppedFrame() {
        lock.lock()
        defer { lock.unlock() }
        framesDropped += 1
    }

    /// Get frame processing percentiles
    func frameProcessingPercentiles() -> (p50: TimeInterval, p95: TimeInterval, p99: TimeInterval) {
        lock.lock()
        let times = frameProcessingTimes.sorted()
        lock.unlock()

        guard !times.isEmpty else { return (0, 0, 0) }

        let p50Index = Int(Double(times.count) * 0.50)
        let p95Index = Int(Double(times.count) * 0.95)
        let p99Index = Int(Double(times.count) * 0.99)

        return (
            p50: times[min(p50Index, times.count - 1)],
            p95: times[min(p95Index, times.count - 1)],
            p99: times[min(p99Index, times.count - 1)]
        )
    }

    /// Get ML inference percentiles
    func mlInferencePercentiles() -> (p50: TimeInterval, p95: TimeInterval, p99: TimeInterval) {
        lock.lock()
        let times = mlInferenceTimes.sorted()
        lock.unlock()

        guard !times.isEmpty else { return (0, 0, 0) }

        let p50Index = Int(Double(times.count) * 0.50)
        let p95Index = Int(Double(times.count) * 0.95)
        let p99Index = Int(Double(times.count) * 0.99)

        return (
            p50: times[min(p50Index, times.count - 1)],
            p95: times[min(p95Index, times.count - 1)],
            p99: times[min(p99Index, times.count - 1)]
        )
    }

    /// Get total dropped frames
    func totalDroppedFrames() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return framesDropped
    }

    /// Reset all metrics
    func reset() {
        lock.lock()
        defer { lock.unlock() }

        frameProcessingTimes.removeAll()
        mlInferenceTimes.removeAll()
        framesDropped = 0
    }
}
