//
//  LibraryError.swift
//  Loominance
//
//  Recording library related errors
//

import Foundation

/// Errors that can occur during library operations
enum LibraryError: LocalizedError, Error {
    /// Storage is full
    case storageFull

    /// Write permission denied
    case writePermissionDenied

    /// Recording not found in library
    case recordingNotFound(id: UUID)

    /// Failed to save recording
    case saveFailed(reason: String)

    /// Failed to delete recording
    case deleteFailed(reason: String)

    /// Database migration failed
    case migrationFailed(reason: String)

    /// Failed to generate thumbnail
    case thumbnailGenerationFailed

    /// Invalid recording metadata
    case invalidMetadata(reason: String)

    /// Storage quota exceeded
    case quotaExceeded(currentSize: Int64, maxSize: Int64)

    var errorDescription: String? {
        switch self {
        case .storageFull:
            return "Storage is full. Cannot save recording."
        case .writePermissionDenied:
            return "Permission to write to storage was denied."
        case .recordingNotFound(let id):
            return "Recording with ID \(id) was not found in the library."
        case .saveFailed(let reason):
            return "Failed to save recording: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete recording: \(reason)"
        case .migrationFailed(let reason):
            return "Database migration failed: \(reason)"
        case .thumbnailGenerationFailed:
            return "Failed to generate thumbnail for the recording."
        case .invalidMetadata(let reason):
            return "Invalid recording metadata: \(reason)"
        case .quotaExceeded(let currentSize, let maxSize):
            let formatter = ByteCountFormatter()
            let current = formatter.string(fromByteCount: currentSize)
            let max = formatter.string(fromByteCount: maxSize)
            return "Storage quota exceeded: \(current) of \(max) used."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .storageFull:
            return "Delete old recordings or free up disk space."
        case .writePermissionDenied:
            return "Check app permissions in System Settings."
        case .recordingNotFound:
            return "Refresh the library or check if the recording was deleted."
        case .saveFailed:
            return "Check disk space and try again."
        case .deleteFailed:
            return "Close any apps using this recording and try again."
        case .migrationFailed:
            return "Try restarting the app. Your data may need to be recovered."
        case .thumbnailGenerationFailed:
            return "The thumbnail will be regenerated when viewing the recording."
        case .invalidMetadata:
            return "This is an internal error. Please report this issue."
        case .quotaExceeded:
            return "Delete old recordings to free up space."
        }
    }
}
