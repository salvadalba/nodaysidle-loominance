//
//  PasteboardServiceProtocol.swift
//  Loominance
//
//  Protocol for clipboard/pasteboard operations
//

import Combine
import Foundation

/// Result of a pasteboard operation
struct PasteboardResult: Equatable {
    /// Whether the operation succeeded
    let success: Bool

    /// The file URL that was copied (if applicable)
    let fileURL: URL?

    /// Pasteboard change count after operation
    let changeCount: Int
}

/// Protocol for pasteboard service
protocol PasteboardServiceProtocol: AnyObject {

    /// Publisher for pasteboard changes
    var changePublisher: AnyPublisher<Int, Never> { get }

    /// Copy a file URL to the pasteboard
    /// - Parameter url: File URL to copy
    /// - Returns: Publisher that emits result or error
    func copyToPasteboard(url: URL) -> AnyPublisher<PasteboardResult, PasteboardError>

    /// Copy multiple file URLs to the pasteboard
    /// - Parameter urls: File URLs to copy
    /// - Returns: Publisher that emits result or error
    func copyToPasteboard(urls: [URL]) -> AnyPublisher<PasteboardResult, PasteboardError>

    /// Check if pasteboard contains file URLs
    /// - Returns: True if pasteboard has file URLs
    func hasFileURLs() -> Bool

    /// Get file URLs from pasteboard
    /// - Returns: Array of file URLs, empty if none
    func getFileURLs() -> [URL]

    /// Clear the pasteboard
    func clear()

    /// Start monitoring pasteboard for drag operations
    func startDragSession(with url: URL)

    /// End drag session
    func endDragSession()
}
