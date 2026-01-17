//
//  PredictionError.swift
//  Loominance
//
//  Core ML prediction related errors
//

import Foundation

/// Errors that can occur during Core ML prediction operations
enum PredictionError: LocalizedError, Error {
    /// Failed to load the Core ML model
    case modelLoadFailed(reason: String)

    /// Invalid input provided to the model
    case invalidInput(reason: String)

    /// Inference operation timed out (exceeded 100ms)
    case inferenceTimeout

    /// Model is not loaded
    case modelNotLoaded

    /// Prediction buffer is exhausted
    case bufferExhausted

    /// Invalid cursor history data
    case invalidCursorHistory

    /// Metal compute backend unavailable
    case metalUnavailable

    /// Model compilation failed
    case compilationFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let reason):
            return "Failed to load the prediction model: \(reason)"
        case .invalidInput(let reason):
            return "Invalid input for prediction: \(reason)"
        case .inferenceTimeout:
            return "Prediction took too long and was cancelled. The system may be under heavy load."
        case .modelNotLoaded:
            return "The prediction model has not been loaded yet."
        case .bufferExhausted:
            return "Prediction buffer exhausted. Too many prediction requests."
        case .invalidCursorHistory:
            return "Invalid cursor history data provided for prediction."
        case .metalUnavailable:
            return "Metal GPU acceleration is unavailable on this device."
        case .compilationFailed(let reason):
            return "Model compilation failed: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .modelLoadFailed:
            return "Try restarting the app. If the problem persists, reinstall the application."
        case .invalidInput:
            return "This is an internal error. Please report this issue."
        case .inferenceTimeout:
            return "Close other applications to free up system resources."
        case .modelNotLoaded:
            return "Wait for the app to finish loading or restart the app."
        case .bufferExhausted:
            return "Wait a moment and try again."
        case .invalidCursorHistory:
            return "This is an internal error. Please report this issue."
        case .metalUnavailable:
            return "Ensure you are running on Apple Silicon hardware."
        case .compilationFailed:
            return "Try restarting the app or reinstalling it."
        }
    }
}
