//
//  PredictionService.swift
//  Loominance
//
//  Core ML-based cursor prediction service
//

import Combine
import CoreGraphics
import CoreML
import CoreVideo
import Foundation

/// Default implementation of PredictionService using heuristic-based prediction
/// This serves as a placeholder until a trained Core ML model is available
final class PredictionService: PredictionServiceProtocol {

    // MARK: - Properties

    private(set) var isModelLoaded: Bool = false

    private let modelStateSubject = CurrentValueSubject<PredictionModelState, Never>(.notLoaded)
    var modelStatePublisher: AnyPublisher<PredictionModelState, Never> {
        modelStateSubject.eraseToAnyPublisher()
    }

    private var cursorHistory: [CursorState] = []
    private let maxHistorySize = 60  // 1 second at 60fps
    private let predictionQueue = DispatchQueue(
        label: "com.loominance.prediction", qos: .userInitiated)
    private let historyLock = NSLock()

    // Heuristic model parameters
    private let velocityThreshold: CGFloat = 50.0  // pixels per second
    private let predictionHorizon: TimeInterval = 0.3  // predict 300ms ahead
    private let focusZonePadding: CGFloat = 100.0  // padding around cursor

    // MARK: - Initialization

    init() {
        AppLogger.prediction.info("PredictionService initialized with heuristic model")
    }

    // MARK: - PredictionServiceProtocol

    func loadModel() -> AnyPublisher<Void, PredictionError> {
        return Future<Void, PredictionError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.modelLoadFailed(reason: "Service deallocated")))
                return
            }

            self.modelStateSubject.send(.loading)

            // Simulate model loading (heuristic model is instant)
            self.predictionQueue.asyncAfter(deadline: .now() + 0.1) {
                self.isModelLoaded = true
                self.modelStateSubject.send(.ready)
                AppLogger.prediction.info("Heuristic prediction model loaded")
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }

    func predictFocusZone(
        currentFrame: CVPixelBuffer?,
        cursorPosition: CGPoint,
        history: [CursorState]
    ) -> AnyPublisher<FocusZonePrediction, PredictionError> {

        return Future<FocusZonePrediction, PredictionError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.modelNotLoaded))
                return
            }

            guard self.isModelLoaded else {
                promise(.failure(.modelNotLoaded))
                return
            }

            let startTime = CFAbsoluteTimeGetCurrent()

            self.predictionQueue.async {
                // Use heuristic prediction based on velocity
                let prediction = self.heuristicPredict(
                    cursorPosition: cursorPosition,
                    history: history
                )

                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                PerformanceMetrics.shared.recordMLInferenceTime(elapsed)

                // Check for timeout (100ms limit)
                if elapsed > 0.1 {
                    AppLogger.prediction.warning("Prediction exceeded 100ms: \(elapsed * 1000)ms")
                }

                promise(.success(prediction))
            }
        }
        .eraseToAnyPublisher()
    }

    func updateCursorHistory(_ state: CursorState) {
        historyLock.lock()
        defer { historyLock.unlock() }

        cursorHistory.append(state)

        // Trim history if needed
        if cursorHistory.count > maxHistorySize {
            cursorHistory.removeFirst(cursorHistory.count - maxHistorySize)
        }
    }

    func clearHistory() {
        historyLock.lock()
        defer { historyLock.unlock() }
        cursorHistory.removeAll()
    }

    // MARK: - Heuristic Prediction

    private func heuristicPredict(
        cursorPosition: CGPoint,
        history: [CursorState]
    ) -> FocusZonePrediction {

        // Calculate average velocity from recent history
        let velocity = calculateAverageVelocity(from: history)

        // Predict future position based on velocity
        let predictedX = cursorPosition.x + velocity.dx * predictionHorizon
        let predictedY = cursorPosition.y + velocity.dy * predictionHorizon

        // Create focus zone centered on predicted position
        let zoneSize = calculateZoneSize(velocity: velocity)
        let zone = CGRect(
            x: predictedX - zoneSize.width / 2,
            y: predictedY - zoneSize.height / 2,
            width: zoneSize.width,
            height: zoneSize.height
        )

        // Calculate confidence based on velocity consistency
        let confidence = calculateConfidence(history: history)

        // Determine zoom level based on activity
        let zoomLevel = calculateZoomLevel(velocity: velocity)

        // Determine transition type based on velocity magnitude
        let transitionType = determineTransitionType(velocity: velocity)

        return FocusZonePrediction(
            zone: zone,
            confidence: confidence,
            suggestedZoomLevel: zoomLevel,
            transitionType: transitionType,
            predictedDuration: predictionHorizon
        )
    }

    private func calculateAverageVelocity(from history: [CursorState]) -> CGVector {
        guard history.count >= 2 else {
            return .zero
        }

        // Use last 10 samples for velocity calculation
        let recentHistory = Array(history.suffix(10))

        var totalDx: CGFloat = 0
        var totalDy: CGFloat = 0

        for state in recentHistory {
            totalDx += state.velocity.dx
            totalDy += state.velocity.dy
        }

        let count = CGFloat(recentHistory.count)
        return CGVector(dx: totalDx / count, dy: totalDy / count)
    }

    private func calculateZoneSize(velocity: CGVector) -> CGSize {
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)

        // Larger zone when moving fast, smaller when stationary
        let baseSize: CGFloat = 400
        let speedFactor = min(speed / 500, 1.0)  // Normalize speed
        let size = baseSize + speedFactor * 200

        return CGSize(width: size, height: size)
    }

    private func calculateConfidence(history: [CursorState]) -> Float {
        guard history.count >= 5 else {
            return 0.5  // Low confidence with little history
        }

        // Calculate velocity variance
        let velocities = history.suffix(10).map { state -> CGFloat in
            sqrt(state.velocity.dx * state.velocity.dx + state.velocity.dy * state.velocity.dy)
        }

        let mean = velocities.reduce(0, +) / CGFloat(velocities.count)
        let variance =
            velocities.map { pow($0 - mean, 2) }.reduce(0, +) / CGFloat(velocities.count)

        // Lower variance = higher confidence
        let normalizedVariance = min(variance / 10000, 1.0)
        return Float(1.0 - normalizedVariance * 0.5)
    }

    private func calculateZoomLevel(velocity: CGVector) -> Float {
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)

        // Less zoom when moving fast, more when stationary
        if speed < velocityThreshold {
            return 1.6  // More zoom for stationary/slow movement
        } else if speed < velocityThreshold * 3 {
            return 1.4
        } else {
            return 1.2  // Less zoom during fast movement
        }
    }

    private func determineTransitionType(velocity: CGVector) -> TransitionType {
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)

        if speed < velocityThreshold {
            return .easeInOut  // Smooth transition when stationary
        } else if speed < velocityThreshold * 2 {
            return .easeOut
        } else {
            return .easeIn  // Quick transition during fast movement
        }
    }
}
