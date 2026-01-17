//
//  RecordingEntity.swift
//  Loominance
//
//  SwiftData model for recording persistence
//

import CoreGraphics
import Foundation
import SwiftData

@Model
final class RecordingEntity {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// File name
    var fileName: String

    /// Recording duration in seconds
    var duration: TimeInterval

    /// Creation date
    var createdAt: Date

    /// File URL path (stored as string for SwiftData)
    var fileURLPath: String

    /// Thumbnail URL path
    var thumbnailURLPath: String?

    /// File size in bytes
    var fileSize: Int64

    /// Resolution width
    var resolutionWidth: Double

    /// Resolution height
    var resolutionHeight: Double

    /// Frame rate
    var frameRate: Int32

    /// Whether cursor is visible
    var cursorVisible: Bool

    /// Recording title
    var title: String?

    /// Recording description
    var recordingDescription: String?

    /// Tags (stored as JSON string)
    var tagsJSON: String

    /// Related focus zone events
    @Relationship(deleteRule: .cascade)
    var focusZoneEvents: [FocusZoneEventEntity]?

    /// Related export configurations
    @Relationship(deleteRule: .cascade)
    var exportConfigurations: [ExportConfigurationEntity]?

    // MARK: - Computed Properties

    var fileURL: URL {
        URL(fileURLWithPath: fileURLPath)
    }

    var thumbnailURL: URL? {
        guard let path = thumbnailURLPath else { return nil }
        return URL(fileURLWithPath: path)
    }

    var resolution: CGSize {
        CGSize(width: resolutionWidth, height: resolutionHeight)
    }

    var tags: [String] {
        get {
            guard let data = tagsJSON.data(using: .utf8),
                let tags = try? JSONDecoder().decode([String].self, from: data)
            else {
                return []
            }
            return tags
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                let json = String(data: data, encoding: .utf8)
            else {
                tagsJSON = "[]"
                return
            }
            tagsJSON = json
        }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        fileName: String,
        duration: TimeInterval,
        createdAt: Date = Date(),
        fileURL: URL,
        thumbnailURL: URL? = nil,
        fileSize: Int64,
        resolution: CGSize,
        frameRate: Int32,
        cursorVisible: Bool = true,
        title: String? = nil,
        description: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.fileName = fileName
        self.duration = duration
        self.createdAt = createdAt
        self.fileURLPath = fileURL.path
        self.thumbnailURLPath = thumbnailURL?.path
        self.fileSize = fileSize
        self.resolutionWidth = resolution.width
        self.resolutionHeight = resolution.height
        self.frameRate = frameRate
        self.cursorVisible = cursorVisible
        self.title = title
        self.recordingDescription = description

        if let data = try? JSONEncoder().encode(tags),
            let json = String(data: data, encoding: .utf8)
        {
            self.tagsJSON = json
        } else {
            self.tagsJSON = "[]"
        }

        self.focusZoneEvents = []
        self.exportConfigurations = []
    }
}
