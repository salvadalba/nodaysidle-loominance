//
//  LoominanceApp.swift
//  Loominance
//
//  Main application entry point
//

import SwiftData
import SwiftUI

@main
struct LoominanceApp: App {

    /// SwiftData model container for persistence
    let modelContainer: ModelContainer

    init() {
        // Initialize SwiftData container
        do {
            let schema = Schema([
                RecordingEntity.self,
                FocusZoneEventEntity.self,
                ExportConfigurationEntity.self,
                UserSettingsEntity.self,
            ])

            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )

            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            AppLogger.app.info("SwiftData container initialized successfully")
        } catch {
            AppLogger.app.fault(
                "Failed to initialize SwiftData container: \(error.localizedDescription)")
            fatalError("Could not initialize SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Recording commands
            CommandGroup(after: .newItem) {
                Button("Start Recording") {
                    NotificationCenter.default.post(name: .startRecording, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Stop Recording") {
                    NotificationCenter.default.post(name: .stopRecording, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()
            }

            // Quick share commands
            CommandGroup(after: .pasteboard) {
                Button("Quick Share Last Recording") {
                    NotificationCenter.default.post(name: .quickShare, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }

        #if os(macOS)
            Settings {
                SettingsView()
                    .modelContainer(modelContainer)
            }
        #endif
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startRecording = Notification.Name("com.loominance.startRecording")
    static let stopRecording = Notification.Name("com.loominance.stopRecording")
    static let quickShare = Notification.Name("com.loominance.quickShare")
}
