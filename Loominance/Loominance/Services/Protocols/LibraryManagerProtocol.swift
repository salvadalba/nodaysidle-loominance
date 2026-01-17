//
//  LibraryManagerProtocol.swift
//  Loominance
//
//  Protocol for recording library management
//

import Combine
import CoreGraphics
import Foundation

/// Recording metadata for storage
struct RecordingMetadata: Codable, Equatable {
    /// Recording title (auto-generated if not set)
    let title: String?

    /// Recording description
    let description: String?

    /// Tags for organization
    let tags: [String]

    /// Recording resolution
    let resolution: CGSize

    /// Frame rate
    let frameRate: Int32

    /// Whether cursor is visible in recording
    let cursorVisible: Bool

    /// Focus zones captured during recording
    let focusZoneCount: Int

    init(
        title: String? = nil,
        description: String? = nil,
        tags: [String] = [],
        resolution: CGSize,
        frameRate: Int32,
        cursorVisible: Bool = true,
        focusZoneCount: Int = 0
    ) {
        self.title = title
        self.description = description
        self.tags = tags
        self.resolution = resolution
        self.frameRate = frameRate
        self.cursorVisible = cursorVisible
        self.focusZoneCount = focusZoneCount
    }
}

/// Recording entry in the library
struct LibraryRecording: Identifiable, Equatable, Hashable {
    /// Unique identifier
    let id: UUID

    /// File name
    let fileName: String

    /// Recording duration in seconds
    let duration: TimeInterval

    /// Creation date
    let createdAt: Date

    /// File URL
    let fileURL: URL

    /// Thumbnail URL (if generated)
    let thumbnailURL: URL?

    /// File size in bytes
    let fileSize: Int64

    /// Recording metadata
    let metadata: RecordingMetadata

    /// Export configurations applied
    let exportConfigurations: [ExportConfiguration]

    // Hashable conformance - hash only on id
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Library storage information
struct LibraryStorageInfo: Equatable {
    /// Total storage used in bytes
    let totalUsed: Int64

    /// Storage quota in bytes
    let quota: Int64

    /// Number of recordings
    let recordingCount: Int

    /// Percentage of quota used
    var percentageUsed: Double {
        guard quota > 0 else { return 0 }
        return Double(totalUsed) / Double(quota)
    }
}

/// Protocol for library management
protocol LibraryManagerProtocol: AnyObject {

    /// Publisher for library changes
    var libraryPublisher: AnyPublisher<[LibraryRecording], Never> { get }

    /// Publisher for storage info changes
    var storagePublisher: AnyPublisher<LibraryStorageInfo, Never> { get }

    /// Save a new recording to the library
    /// - Parameters:
    ///   - url: Source file URL
    ///   - duration: Recording duration
    ///   - metadata: Recording metadata
    /// - Returns: Publisher that emits the saved recording or error
    func saveRecording(
        url: URL,
        duration: TimeInterval,
        metadata: RecordingMetadata
    ) -> AnyPublisher<LibraryRecording, LibraryError>

    /// Fetch all recordings from the library
    /// - Returns: Publisher that emits recordings or error
    func fetchRecordings() -> AnyPublisher<[LibraryRecording], LibraryError>

    /// Get a specific recording by ID
    /// - Parameter id: Recording ID
    /// - Returns: Recording if found
    func getRecording(id: UUID) -> LibraryRecording?

    /// Update recording metadata
    /// - Parameters:
    ///   - id: Recording ID
    ///   - metadata: New metadata
    /// - Returns: Publisher that emits updated recording or error
    func updateRecording(
        id: UUID,
        metadata: RecordingMetadata
    ) -> AnyPublisher<LibraryRecording, LibraryError>

    /// Delete a recording
    /// - Parameter id: Recording ID
    /// - Returns: Publisher that completes or errors
    func deleteRecording(id: UUID) -> AnyPublisher<Void, LibraryError>

    /// Delete multiple recordings
    /// - Parameter ids: Recording IDs to delete
    /// - Returns: Publisher that completes or errors
    func deleteRecordings(ids: [UUID]) -> AnyPublisher<Void, LibraryError>

    /// Search recordings
    /// - Parameter query: Search query
    /// - Returns: Publisher that emits matching recordings
    func searchRecordings(query: String) -> AnyPublisher<[LibraryRecording], LibraryError>

    /// Get storage information
    /// - Returns: Current storage info
    func getStorageInfo() -> LibraryStorageInfo

    /// Clean up old recordings to stay within quota
    /// - Parameter targetBytes: Target bytes to free
    /// - Returns: Publisher that emits freed bytes or error
    func cleanupOldRecordings(targetBytes: Int64) -> AnyPublisher<Int64, LibraryError>

    /// Generate thumbnail for a recording
    /// - Parameter id: Recording ID
    /// - Returns: Publisher that emits thumbnail URL or error
    func generateThumbnail(for id: UUID) -> AnyPublisher<URL, LibraryError>
}
