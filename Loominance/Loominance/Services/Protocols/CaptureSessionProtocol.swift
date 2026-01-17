//
//  CaptureSessionProtocol.swift
//  Loominance
//
//  Protocol for screen capture service
//

import Combine
import CoreGraphics
import CoreVideo
import Foundation

/// Represents an active capture session
protocol CaptureSessionProtocol {
    /// Unique identifier for the session
    var sessionId: UUID { get }

    /// Display being captured
    var displayId: CGDirectDisplayID { get }

    /// Target frame rate
    var frameRate: Int32 { get }

    /// Capture region
    var captureRect: CGRect { get }

    /// Whether the session is currently active
    var isActive: Bool { get }

    /// Publisher for captured frames
    var framePublisher: AnyPublisher<CapturedFrame, Never> { get }
}

/// Represents a single captured frame
struct CapturedFrame {
    /// The pixel buffer containing frame data
    let pixelBuffer: CVPixelBuffer

    /// Timestamp when frame was captured
    let timestamp: TimeInterval

    /// Frame sequence number
    let frameNumber: Int

    /// Current cursor position at capture time
    let cursorPosition: CGPoint
}

/// Protocol for managing screen capture operations
protocol CaptureServiceProtocol: AnyObject {

    /// Current capture session, if any
    var currentSession: CaptureSessionProtocol? { get }

    /// Publisher for capture state changes
    var statePublisher: AnyPublisher<CaptureState, Never> { get }

    /// Start capturing the specified display
    /// - Parameters:
    ///   - displayId: The display to capture
    ///   - frameRate: Target frames per second (default: 60)
    ///   - captureRect: Region to capture (default: full display)
    /// - Returns: Publisher that emits the capture session or error
    func startCapture(
        displayId: CGDirectDisplayID,
        frameRate: Int32,
        captureRect: CGRect
    ) -> AnyPublisher<CaptureSessionProtocol, CaptureError>

    /// Stop the current capture session
    /// - Returns: Publisher that completes when stopped or emits error
    func stopCapture() -> AnyPublisher<Void, CaptureError>

    /// Get list of available displays
    /// - Returns: Array of available display IDs
    func availableDisplays() -> [CGDirectDisplayID]

    /// Get display info
    /// - Parameter displayId: The display to get info for
    /// - Returns: Display info if available
    func displayInfo(for displayId: CGDirectDisplayID) -> DisplayInfo?
}

/// Represents capture state
enum CaptureState: Equatable {
    case idle
    case starting
    case capturing
    case stopping
    case error(String)
}

/// Display information
struct DisplayInfo: Equatable {
    let displayId: CGDirectDisplayID
    let name: String
    let bounds: CGRect
    let isMain: Bool
    let isOnline: Bool
}
