//
//  ExportError.swift
//  Loominance
//
//  Video export related errors
//

import Foundation

/// Errors that can occur during video export operations
enum ExportError: LocalizedError, Error {
    /// Recording file not found
    case fileNotFound(url: URL)

    /// Video encoding failed
    case encodingFailed(reason: String)

    /// Not enough disk space
    case diskFull

    /// Export was cancelled by user
    case cancelled

    /// Invalid export preset configuration
    case invalidPreset(reason: String)

    /// Failed to create asset writer
    case assetWriterCreationFailed(reason: String)

    /// Failed to create asset reader
    case assetReaderCreationFailed(reason: String)

    /// Export already in progress
    case exportInProgress

    /// Invalid video format
    case invalidVideoFormat(reason: String)

    /// Watermark image not found
    case watermarkNotFound

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Recording file not found at: \(url.lastPathComponent)"
        case .encodingFailed(let reason):
            return "Video encoding failed: \(reason)"
        case .diskFull:
            return "Not enough disk space to export the video."
        case .cancelled:
            return "Export was cancelled."
        case .invalidPreset(let reason):
            return "Invalid export preset: \(reason)"
        case .assetWriterCreationFailed(let reason):
            return "Failed to create video writer: \(reason)"
        case .assetReaderCreationFailed(let reason):
            return "Failed to read video: \(reason)"
        case .exportInProgress:
            return "An export is already in progress."
        case .invalidVideoFormat(let reason):
            return "Invalid video format: \(reason)"
        case .watermarkNotFound:
            return "Watermark image could not be found."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "The recording may have been deleted. Check your library."
        case .encodingFailed:
            return "Try exporting with a different preset."
        case .diskFull:
            return "Free up disk space and try again."
        case .cancelled:
            return "Start a new export when ready."
        case .invalidPreset:
            return "Select a different export preset."
        case .assetWriterCreationFailed:
            return "Restart the app and try again."
        case .assetReaderCreationFailed:
            return "The recording file may be corrupted."
        case .exportInProgress:
            return "Wait for the current export to complete or cancel it."
        case .invalidVideoFormat:
            return "The recording may be corrupted. Try recording again."
        case .watermarkNotFound:
            return "Check that the watermark image exists or disable watermark."
        }
    }
}
