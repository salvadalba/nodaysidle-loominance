//
//  PredictionServiceProtocol.swift
//  Loominance
//
//  Protocol for Core ML cursor prediction service
//

import Combine
import CoreGraphics
import CoreVideo
import Foundation

/// Cursor state for prediction input
struct CursorState: Codable, Equatable {
    /// Current cursor position
    let position: CGPoint

    /// Timestamp of this state
    let timestamp: TimeInterval

    /// Velocity vector (points per second)
    let velocity: CGVector

    init(position: CGPoint, timestamp: TimeInterval, velocity: CGVector = .zero) {
        self.position = position
        self.timestamp = timestamp
        self.velocity = velocity
    }

    /// Calculate velocity from previous cursor state
    static func calculateVelocity(
        from previous: CursorState, to current: CGPoint, at timestamp: TimeInterval
    ) -> CGVector {
        let deltaTime = timestamp - previous.timestamp
        guard deltaTime > 0 else { return .zero }

        let dx = (current.x - previous.position.x) / deltaTime
        let dy = (current.y - previous.position.y) / deltaTime

        return CGVector(dx: dx, dy: dy)
    }
}

/// Transition animation type for focus zone changes
enum TransitionType: String, Codable, CaseIterable {
    case instant
    case easeIn
    case easeOut
    case easeInOut
}

/// Focus zone event recorded during capture
struct FocusZoneEvent: Codable, Equatable {
    /// Timestamp of the event
    let timestamp: TimeInterval

    /// Predicted focus zone rectangle
    let zone: CGRect

    /// Zoom level applied (1.0 = no zoom)
    let zoomLevel: Float

    /// Transition animation type
    let transitionType: TransitionType
}

/// Result of focus zone prediction
struct FocusZonePrediction: Equatable {
    /// Predicted focus zone rectangle
    let zone: CGRect

    /// Confidence score (0.0 - 1.0)
    let confidence: Float

    /// Suggested zoom level
    let suggestedZoomLevel: Float

    /// Suggested transition type
    let transitionType: TransitionType

    /// Time this prediction is valid for
    let predictedDuration: TimeInterval
}

/// Protocol for Core ML prediction service
protocol PredictionServiceProtocol: AnyObject {

    /// Whether the model is loaded and ready
    var isModelLoaded: Bool { get }

    /// Publisher for model loading state
    var modelStatePublisher: AnyPublisher<PredictionModelState, Never> { get }

    /// Load the Core ML model
    /// - Returns: Publisher that completes when loaded or emits error
    func loadModel() -> AnyPublisher<Void, PredictionError>

    /// Predict focus zone based on current state
    /// - Parameters:
    ///   - currentFrame: Current frame buffer
    ///   - cursorPosition: Current cursor position
    ///   - history: History of recent cursor states
    /// - Returns: Publisher that emits prediction or error
    func predictFocusZone(
        currentFrame: CVPixelBuffer?,
        cursorPosition: CGPoint,
        history: [CursorState]
    ) -> AnyPublisher<FocusZonePrediction, PredictionError>

    /// Update cursor history
    /// - Parameter state: New cursor state to add
    func updateCursorHistory(_ state: CursorState)

    /// Clear cursor history
    func clearHistory()
}

/// Model loading state
enum PredictionModelState: Equatable {
    case notLoaded
    case loading
    case ready
    case error(String)
}
