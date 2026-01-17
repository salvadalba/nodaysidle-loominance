//
//  FocusZoneEventEntity.swift
//  Loominance
//
//  SwiftData model for focus zone events during recording
//

import CoreGraphics
import Foundation
import SwiftData

@Model
final class FocusZoneEventEntity {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Timestamp within the recording
    var timestamp: TimeInterval

    /// Zone origin X
    var zoneX: Double

    /// Zone origin Y
    var zoneY: Double

    /// Zone width
    var zoneWidth: Double

    /// Zone height
    var zoneHeight: Double

    /// Zoom level applied
    var zoomLevel: Float

    /// Transition type (stored as raw value)
    var transitionTypeRaw: String

    /// Parent recording
    var recording: RecordingEntity?

    // MARK: - Computed Properties

    var zone: CGRect {
        CGRect(x: zoneX, y: zoneY, width: zoneWidth, height: zoneHeight)
    }

    var transitionType: TransitionType {
        get {
            TransitionType(rawValue: transitionTypeRaw) ?? .easeInOut
        }
        set {
            transitionTypeRaw = newValue.rawValue
        }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        zone: CGRect,
        zoomLevel: Float,
        transitionType: TransitionType
    ) {
        self.id = id
        self.timestamp = timestamp
        self.zoneX = zone.origin.x
        self.zoneY = zone.origin.y
        self.zoneWidth = zone.width
        self.zoneHeight = zone.height
        self.zoomLevel = zoomLevel
        self.transitionTypeRaw = transitionType.rawValue
    }

    /// Convert to value type
    func toFocusZoneEvent() -> FocusZoneEvent {
        FocusZoneEvent(
            timestamp: timestamp,
            zone: zone,
            zoomLevel: zoomLevel,
            transitionType: transitionType
        )
    }
}
