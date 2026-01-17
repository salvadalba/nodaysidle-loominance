//
//  CaptureError.swift
//  Loominance
//
//  Screen capture related errors
//

import Foundation

/// Errors that can occur during screen capture operations
enum CaptureError: LocalizedError, Error {
    /// Screen recording permission was denied by the user
    case permissionDenied
    
    /// The specified display could not be found
    case displayNotFound(displayId: UUID)
    
    /// A capture session is already active
    case captureAlreadyActive
    
    /// No active capture session exists
    case noActiveCapture
    
    /// Failed to write captured frame data
    case writeFailed(reason: String)
    
    /// Frame capture timed out
    case captureTimeout
    
    /// Invalid capture configuration
    case invalidConfiguration(reason: String)
    
    /// Frame buffer allocation failed
    case bufferAllocationFailed
    
    /// Display stream creation failed
    case displayStreamCreationFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission was denied. Please enable screen recording access in System Settings > Privacy & Security > Screen Recording."
        case .displayNotFound(let displayId):
            return "The display with ID \(displayId) could not be found. Please select a different display."
        case .captureAlreadyActive:
            return "A recording session is already in progress. Please stop the current recording before starting a new one."
        case .noActiveCapture:
            return "No active recording session found."
        case .writeFailed(let reason):
            return "Failed to write captured data: \(reason)"
        case .captureTimeout:
            return "The capture operation timed out. Please try again."
        case .invalidConfiguration(let reason):
            return "Invalid capture configuration: \(reason)"
        case .bufferAllocationFailed:
            return "Failed to allocate frame buffer. The system may be low on memory."
        case .displayStreamCreationFailed(let reason):
            return "Failed to create display stream: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Open System Settings and enable screen recording for Loominance."
        case .displayNotFound:
            return "Try selecting a different display or reconnecting your monitor."
        case .captureAlreadyActive:
            return "Stop the current recording first."
        case .noActiveCapture:
            return "Start a new recording session."
        case .writeFailed:
            return "Check available disk space and try again."
        case .captureTimeout:
            return "Restart the app and try again."
        case .invalidConfiguration:
            return "Reset recording settings to defaults."
        case .bufferAllocationFailed:
            return "Close other applications to free up memory."
        case .displayStreamCreationFailed:
            return "Restart the app and try again."
        }
    }
}
