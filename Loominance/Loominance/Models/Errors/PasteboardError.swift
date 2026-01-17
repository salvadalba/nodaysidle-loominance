//
//  PasteboardError.swift
//  Loominance
//
//  Pasteboard (clipboard) related errors
//

import Foundation

/// Errors that can occur during pasteboard operations
enum PasteboardError: LocalizedError, Error {
    /// Pasteboard is unavailable
    case pasteboardUnavailable

    /// File type not supported for clipboard
    case fileTypeNotSupported(type: String)

    /// Failed to copy to clipboard
    case copyFailed(reason: String)

    /// File not found for clipboard operation
    case fileNotFound(url: URL)

    /// Pasteboard is busy
    case pasteboardBusy

    var errorDescription: String? {
        switch self {
        case .pasteboardUnavailable:
            return "The system clipboard is not available."
        case .fileTypeNotSupported(let type):
            return "File type '\(type)' is not supported for clipboard operations."
        case .copyFailed(let reason):
            return "Failed to copy to clipboard: \(reason)"
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .pasteboardBusy:
            return "The clipboard is currently busy with another operation."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .pasteboardUnavailable:
            return "Try again in a moment."
        case .fileTypeNotSupported:
            return "Export to a supported format first."
        case .copyFailed:
            return "Try copying again."
        case .fileNotFound:
            return "The recording may have been deleted."
        case .pasteboardBusy:
            return "Wait a moment and try again."
        }
    }
}
