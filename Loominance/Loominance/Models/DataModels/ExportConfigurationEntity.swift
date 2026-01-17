//
//  ExportConfigurationEntity.swift
//  Loominance
//
//  SwiftData model for export configuration persistence
//

import CoreGraphics
import Foundation
import SwiftData

@Model
final class ExportConfigurationEntity {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Export preset (stored as raw value)
    var presetRaw: String

    /// Whether watermark is included
    var includeWatermark: Bool

    /// Export quality (0.0 - 1.0)
    var quality: Float

    /// Output width
    var outputWidth: Double

    /// Output height
    var outputHeight: Double

    /// Custom bitrate (nil uses preset default)
    var customBitrate: Int?

    /// Frame rate
    var frameRate: Int

    /// Export date
    var exportedAt: Date

    /// Output file path
    var outputFilePath: String?

    /// Parent recording
    var recording: RecordingEntity?

    // MARK: - Computed Properties

    var preset: ExportPreset {
        get {
            ExportPreset(rawValue: presetRaw) ?? .twitter
        }
        set {
            presetRaw = newValue.rawValue
        }
    }

    var outputSize: CGSize {
        CGSize(width: outputWidth, height: outputHeight)
    }

    var outputFileURL: URL? {
        guard let path = outputFilePath else { return nil }
        return URL(fileURLWithPath: path)
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        preset: ExportPreset,
        includeWatermark: Bool = false,
        quality: Float = 0.85,
        outputSize: CGSize? = nil,
        customBitrate: Int? = nil,
        frameRate: Int = 30,
        exportedAt: Date = Date(),
        outputFilePath: String? = nil
    ) {
        self.id = id
        self.presetRaw = preset.rawValue
        self.includeWatermark = includeWatermark
        self.quality = quality

        let size = outputSize ?? preset.resolution
        self.outputWidth = size.width
        self.outputHeight = size.height

        self.customBitrate = customBitrate
        self.frameRate = frameRate
        self.exportedAt = exportedAt
        self.outputFilePath = outputFilePath
    }

    /// Convert to value type
    func toExportConfiguration() -> ExportConfiguration {
        ExportConfiguration(
            preset: preset,
            includeWatermark: includeWatermark,
            quality: quality,
            outputSize: outputSize,
            customBitrate: customBitrate,
            frameRate: frameRate
        )
    }
}
