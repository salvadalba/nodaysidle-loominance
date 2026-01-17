//
//  CinematicEngineProtocol.swift
//  Loominance
//
//  Protocol for cinematic zoom/pan effects engine
//

import Combine
import CoreGraphics
import CoreVideo
import Foundation

/// Result of a cinematic transform operation
struct TransformResult: Equatable {
    /// Transformed pixel buffer
    let pixelBuffer: CVPixelBuffer

    /// Current zoom level
    let currentZoomLevel: Float

    /// Current focus zone
    let currentFocusZone: CGRect

    /// Whether a transition is in progress
    let isTransitioning: Bool

    /// Progress of current transition (0.0 - 1.0)
    let transitionProgress: Float

    static func == (lhs: TransformResult, rhs: TransformResult) -> Bool {
        return lhs.currentZoomLevel == rhs.currentZoomLevel
            && lhs.currentFocusZone == rhs.currentFocusZone
            && lhs.isTransitioning == rhs.isTransitioning
            && lhs.transitionProgress == rhs.transitionProgress
    }
}

/// Configuration for zoom effects
struct ZoomConfiguration: Equatable {
    /// Minimum zoom level (1.0 = no zoom)
    let minZoom: Float

    /// Maximum zoom level
    let maxZoom: Float

    /// Default zoom intensity
    let defaultIntensity: Float

    /// Transition duration in seconds
    let transitionDuration: TimeInterval

    /// Damping factor for rapid changes (0.0 - 1.0)
    let dampingFactor: Float

    static let `default` = ZoomConfiguration(
        minZoom: 1.0,
        maxZoom: 2.0,
        defaultIntensity: 1.5,
        transitionDuration: 0.3,
        dampingFactor: 0.8
    )
}

/// Errors specific to transform operations
enum TransformError: LocalizedError, Error {
    case transformFailed(reason: String)
    case bufferPoolExhausted
    case invalidInputBuffer
    case contextCreationFailed

    var errorDescription: String? {
        switch self {
        case .transformFailed(let reason):
            return "Transform failed: \(reason)"
        case .bufferPoolExhausted:
            return "Buffer pool exhausted. Too many transforms in progress."
        case .invalidInputBuffer:
            return "Invalid input buffer for transform."
        case .contextCreationFailed:
            return "Failed to create graphics context for transform."
        }
    }
}

/// Protocol for cinematic zoom/pan engine
protocol CinematicEngineProtocol: AnyObject {

    /// Current zoom configuration
    var configuration: ZoomConfiguration { get set }

    /// Current zoom level
    var currentZoomLevel: Float { get }

    /// Current focus zone
    var currentFocusZone: CGRect { get }

    /// Publisher for transform state changes
    var statePublisher: AnyPublisher<CinematicState, Never> { get }

    /// Apply zoom effect to a frame
    /// - Parameters:
    ///   - frame: Input pixel buffer
    ///   - focusZone: Target focus zone
    ///   - intensity: Zoom intensity (uses default if nil)
    /// - Returns: Transformed pixel buffer
    func applyZoomEffect(
        frame: CVPixelBuffer,
        focusZone: CGRect,
        intensity: Float?
    ) -> Result<TransformResult, TransformError>

    /// Set the target focus zone with transition
    /// - Parameters:
    ///   - zone: Target focus zone
    ///   - transitionType: Animation type
    func setTargetFocusZone(_ zone: CGRect, transitionType: TransitionType)

    /// Update the zoom intensity
    /// - Parameter intensity: New intensity value (clamped to min/max)
    func setZoomIntensity(_ intensity: Float)

    /// Reset to default state (no zoom, center focus)
    func reset()

    /// Prepare buffer pool for recording
    /// - Parameters:
    ///   - width: Frame width
    ///   - height: Frame height
    ///   - bufferCount: Number of buffers in pool
    func prepareBufferPool(width: Int, height: Int, bufferCount: Int)

    /// Release buffer pool resources
    func releaseBufferPool()
}

/// State of the cinematic engine
enum CinematicState: Equatable {
    case idle
    case processing
    case transitioning(progress: Float)
    case error(String)
}
