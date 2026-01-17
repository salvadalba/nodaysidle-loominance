//
//  UserSettingsEntity.swift
//  Loominance
//
//  SwiftData model for user settings persistence
//

import Foundation
import SwiftData

@Model
final class UserSettingsEntity {
    /// Unique identifier (singleton pattern - always use same ID)
    @Attribute(.unique) var id: UUID

    /// Auto-save recordings after stopping
    var autoSave: Bool

    /// Default export preset (stored as raw value)
    var defaultPresetRaw: String

    /// Default zoom intensity
    var defaultZoomIntensity: Float

    /// Show cursor in recording
    var showCursorInRecording: Bool

    /// Enable auto-zoom based on ML predictions
    var enableAutoZoom: Bool

    /// Storage location path
    var storageLocationPath: String?

    /// Maximum storage quota in bytes
    var storageQuotaBytes: Int64

    /// Auto-cleanup old recordings when quota exceeded
    var autoCleanup: Bool

    /// Show onboarding on next launch
    var showOnboarding: Bool

    /// Global keyboard shortcut enabled
    var globalShortcutsEnabled: Bool

    /// Last used display ID
    var lastDisplayId: UInt32?

    /// Last recording region (stored as JSON)
    var lastRecordingRegionJSON: String?

    // MARK: - Computed Properties

    var defaultPreset: ExportPreset {
        get {
            ExportPreset(rawValue: defaultPresetRaw) ?? .twitter
        }
        set {
            defaultPresetRaw = newValue.rawValue
        }
    }

    var storageLocation: URL? {
        get {
            guard let path = storageLocationPath else {
                // Default to Application Support
                return FileManager.default.urls(
                    for: .applicationSupportDirectory, in: .userDomainMask
                ).first?
                .appendingPathComponent("Loominance", isDirectory: true)
                .appendingPathComponent("Recordings", isDirectory: true)
            }
            return URL(fileURLWithPath: path)
        }
        set {
            storageLocationPath = newValue?.path
        }
    }

    // MARK: - Initialization

    /// Singleton ID for user settings
    static let settingsId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    init() {
        self.id = UserSettingsEntity.settingsId
        self.autoSave = true
        self.defaultPresetRaw = ExportPreset.twitter.rawValue
        self.defaultZoomIntensity = 1.5
        self.showCursorInRecording = true
        self.enableAutoZoom = true
        self.storageLocationPath = nil
        self.storageQuotaBytes = 10 * 1024 * 1024 * 1024  // 10 GB default
        self.autoCleanup = false
        self.showOnboarding = true
        self.globalShortcutsEnabled = true
        self.lastDisplayId = nil
        self.lastRecordingRegionJSON = nil
    }

    /// Create default settings
    static func createDefault() -> UserSettingsEntity {
        return UserSettingsEntity()
    }
}
