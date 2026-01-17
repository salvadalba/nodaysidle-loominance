//
//  PermissionManager.swift
//  Loominance
//
//  Manages screen recording and other permission requests
//

import Combine
import CoreGraphics
import Foundation
import ScreenCaptureKit

/// Permission state for screen recording
enum PermissionState: Equatable, CustomStringConvertible {
    case unknown
    case notDetermined
    case granted
    case denied

    var description: String {
        switch self {
        case .unknown: return "unknown"
        case .notDetermined: return "notDetermined"
        case .granted: return "granted"
        case .denied: return "denied"
        }
    }
}

/// Manages permission requests for screen recording
@MainActor
final class PermissionManager: ObservableObject {

    static let shared = PermissionManager()

    @Published private(set) var screenRecordingPermission: PermissionState = .unknown

    private var cancellables = Set<AnyCancellable>()

    private init() {
        Task {
            await checkScreenRecordingPermission()
        }
    }

    // MARK: - Screen Recording Permission

    /// Check current screen recording permission status
    func checkScreenRecordingPermission() async {
        #if os(macOS)
            // Use ScreenCaptureKit to check permission - this is more reliable
            do {
                // Attempting to get shareable content will tell us if we have permission
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false, 
                    onScreenWindowsOnly: true
                )
                
                // If we can get content, we have permission
                screenRecordingPermission = .granted
                AppLogger.app.info("Screen recording permission: granted")
            } catch {
                // If we get an error, check what kind
                let errorString = error.localizedDescription.lowercased()
                
                if errorString.contains("denied") || errorString.contains("permission") {
                    screenRecordingPermission = .denied
                    AppLogger.app.warning("Screen recording permission: denied")
                } else {
                    screenRecordingPermission = .notDetermined
                    AppLogger.app.info("Screen recording permission: not determined")
                }
            }
        #endif
    }

    /// Request screen recording permission using ScreenCaptureKit
    /// This is the most reliable way to trigger the permission dialog
    /// - Returns: Publisher that emits the permission result
    func requestScreenRecordingPermission() -> AnyPublisher<PermissionState, Never> {
        return Future<PermissionState, Never> { @MainActor [weak self] promise in
            guard let self = self else {
                promise(.success(.denied))
                return
            }
            
            #if os(macOS)
                Task {
                    do {
                        // This will trigger the permission dialog if not already granted
                        AppLogger.app.info("Requesting screen recording permission...")
                        
                        let content = try await SCShareableContent.excludingDesktopWindows(
                            false, 
                            onScreenWindowsOnly: true
                        )
                        
                        // Success means permission granted
                        await MainActor.run {
                            self.screenRecordingPermission = .granted
                            AppLogger.app.info("Screen recording permission granted!")
                        }
                        promise(.success(.granted))
                        
                    } catch {
                        // Check the error type
                        let errorString = error.localizedDescription
                        AppLogger.app.error("Screen recording permission error: \(errorString)")
                        
                        // Check if it's a permissions error
                        if errorString.lowercased().contains("denied") 
                            || errorString.lowercased().contains("permission") 
                            || errorString.lowercased().contains("user declined") {
                            
                            await MainActor.run {
                                self.screenRecordingPermission = .denied
                                AppLogger.app.warning("Screen recording permission denied by user")
                            }
                            promise(.success(.denied))
                        } else {
                            // Some other error
                            await MainActor.run {
                                self.screenRecordingPermission = .denied
                            }
                            promise(.success(.denied))
                        }
                    }
                }
            #else
                promise(.success(.denied))
            #endif
        }
        .eraseToAnyPublisher()
    }

    /// Open System Settings to the Screen Recording pane
    func openSystemSettingsScreenRecording() {
        #if os(macOS)
            // Updated URL for modern macOS
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
                AppLogger.app.info("Opening System Settings for screen recording permission")
            }
        #endif
    }

    /// Publisher for permission state changes
    var permissionPublisher: AnyPublisher<PermissionState, Never> {
        $screenRecordingPermission.eraseToAnyPublisher()
    }
    
    /// Reset permission check (useful for debugging)
    func recheckPermission() {
        Task {
            await checkScreenRecordingPermission()
        }
    }
}

#if os(macOS)
    import AppKit
#endif
