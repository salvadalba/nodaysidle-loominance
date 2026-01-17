//
//  ExportServiceProtocol.swift
//  Loominance
//
//  Protocol for video export service
//

import Combine
import CoreGraphics
import Foundation

/// Export preset for different social platforms
enum ExportPreset: String, CaseIterable, Codable {
    case instagramSquare = "Instagram (Square 1:1)"
    case instagramPortrait = "Instagram (Portrait 4:5)"
    case tikTok = "TikTok (9:16)"
    case twitter = "Twitter (16:9)"
    case youTube = "YouTube (16:9)"
    case linkedin = "LinkedIn (16:9)"
    case custom = "Custom"

    /// Target resolution for this preset
    var resolution: CGSize {
        switch self {
        case .instagramSquare:
            return CGSize(width: 1080, height: 1080)
        case .instagramPortrait:
            return CGSize(width: 1080, height: 1350)
        case .tikTok:
            return CGSize(width: 1080, height: 1920)
        case .twitter:
            return CGSize(width: 1280, height: 720)
        case .youTube:
            return CGSize(width: 1920, height: 1080)
        case .linkedin:
            return CGSize(width: 1920, height: 1080)
        case .custom:
            return CGSize(width: 1920, height: 1080)
        }
    }

    /// Aspect ratio for this preset
    var aspectRatio: CGFloat {
        return resolution.width / resolution.height
    }

    /// Target bitrate in bits per second
    var targetBitrate: Int {
        switch self {
        case .instagramSquare, .instagramPortrait:
            return 6_000_000  // 6 Mbps
        case .tikTok:
            return 8_000_000  // 8 Mbps
        case .twitter:
            return 5_000_000  // 5 Mbps
        case .youTube, .linkedin:
            return 12_000_000  // 12 Mbps
        case .custom:
            return 10_000_000  // 10 Mbps
        }
    }

    /// Platform-specific codec preference
    var preferHEVC: Bool {
        switch self {
        case .instagramSquare, .instagramPortrait, .tikTok:
            return false  // H.264 for wider compatibility
        default:
            return true  // HEVC for better compression
        }
    }
}

/// Export configuration combining preset and custom options
struct ExportConfiguration: Codable, Equatable {
    /// Export preset
    let preset: ExportPreset

    /// Whether to include watermark
    let includeWatermark: Bool

    /// Export quality (0.0 - 1.0)
    let quality: Float

    /// Output size (overrides preset if custom)
    let outputSize: CGSize

    /// Custom bitrate (overrides preset if set)
    let customBitrate: Int?

    /// Frame rate for export
    let frameRate: Int

    init(
        preset: ExportPreset,
        includeWatermark: Bool = false,
        quality: Float = 0.85,
        outputSize: CGSize? = nil,
        customBitrate: Int? = nil,
        frameRate: Int = 30
    ) {
        self.preset = preset
        self.includeWatermark = includeWatermark
        self.quality = quality
        self.outputSize = outputSize ?? preset.resolution
        self.customBitrate = customBitrate
        self.frameRate = frameRate
    }

    static let `default` = ExportConfiguration(preset: .twitter)
}

/// Export progress information
struct ExportProgress: Equatable {
    /// Recording ID being exported
    let recordingId: UUID

    /// Progress percentage (0.0 - 1.0)
    let progress: Double

    /// Estimated time remaining in seconds
    let estimatedTimeRemaining: TimeInterval?

    /// Current phase of export
    let phase: ExportPhase

    /// Output file URL (available when complete)
    let outputURL: URL?

    /// Convenience alias for progress
    var percentComplete: Double {
        return progress
    }
}

/// Export phases
enum ExportPhase: String, Equatable {
    case preparing = "Preparing"
    case encoding = "Encoding"
    case writing = "Writing"
    case finalizing = "Finalizing"
    case complete = "Complete"
    case failed = "Failed"
    case cancelled = "Cancelled"

    var description: String {
        return rawValue
    }
}

/// Protocol for video export service
protocol ExportServiceProtocol: AnyObject {

    /// Currently active export, if any
    var currentExport: UUID? { get }

    /// Publisher for export progress
    var progressPublisher: AnyPublisher<ExportProgress, Never> { get }

    /// Export a recording to MP4
    /// - Parameters:
    ///   - recordingId: ID of the recording to export
    ///   - configuration: Export configuration
    ///   - outputURL: Destination URL (optional, auto-generated if nil)
    /// - Returns: Publisher that emits progress and completes or errors
    func exportToMP4(
        recordingId: UUID,
        configuration: ExportConfiguration,
        outputURL: URL?
    ) -> AnyPublisher<ExportProgress, ExportError>

    /// Cancel the current export
    func cancelExport()

    /// Get available export presets
    /// - Returns: Array of available presets
    func availablePresets() -> [ExportPreset]

    /// Validate export configuration
    /// - Parameter configuration: Configuration to validate
    /// - Returns: Validation result
    func validateConfiguration(_ configuration: ExportConfiguration) -> Result<Void, ExportError>
}
