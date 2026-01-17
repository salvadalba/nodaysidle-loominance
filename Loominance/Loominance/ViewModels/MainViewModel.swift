//
//  MainViewModel.swift
//  Loominance
//
//  Main view model for recording coordination
//

import Combine
import CoreGraphics
import Foundation
import SwiftUI

@MainActor
final class MainViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isRecording: Bool = false
    @Published var recordingDuration: String = "00:00:00"
    @Published var selectedDisplay: String?
    @Published var selectedDisplayId: CGDirectDisplayID?
    @Published var availableDisplays: [String] = []
    @Published var showCursor: Bool = true
    @Published var autoZoom: Bool = true
    @Published var zoomIntensity: Float = 1.5

    @Published var permissionGranted: Bool = false
    @Published var showPermissionAlert: Bool = false
    @Published var showSettings: Bool = false
    @Published var errorMessage: String?

    // MARK: - Services

    private let permissionManager = PermissionManager.shared
    private var recordingManager: RecordingManager?

    // MARK: - Private Properties

    private var recordingStartTime: Date?
    private var timerCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var displayIds: [CGDirectDisplayID] = []

    // MARK: - Initialization

    init() {
        setupNotificationObservers()
        setupPermissionObserver()
    }

    // MARK: - Public Methods

    func onAppear() {
        checkPermission()
        loadAvailableDisplays()
    }

    func toggleRecording() {
        print("🔘 Toggle recording called. Current state: \(isRecording)")
        print("🔐 Permission granted: \(permissionGranted)")
        
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func selectDisplay(_ display: String) {
        selectedDisplay = display

        // Find the display ID
        if let index = availableDisplays.firstIndex(of: display), index < displayIds.count {
            selectedDisplayId = displayIds[index]
        }

        AppLogger.app.info("Selected display: \(display)")
    }

    func openSettings() {
        showSettings = true
    }

    func openSystemSettingsPermission() {
        permissionManager.openSystemSettingsScreenRecording()
    }

    // MARK: - Private Methods

    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .startRecording)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.startRecording()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .stopRecording)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.stopRecording()
            }
            .store(in: &cancellables)
    }

    private func setupPermissionObserver() {
        permissionManager.permissionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.permissionGranted = (state == .granted)
            }
            .store(in: &cancellables)
    }

    private func checkPermission() {
        print("🔍 Checking permissions...")
        Task {
            await permissionManager.checkScreenRecordingPermission()
            permissionGranted = (permissionManager.screenRecordingPermission == .granted)
            
            print("📊 Permission state: \(permissionManager.screenRecordingPermission)")
            print("✅ Permission granted flag: \(permissionGranted)")

            if !permissionGranted {
                print("⚠️ Permission not granted, requesting...")
                permissionManager.requestScreenRecordingPermission()
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] state in
                        self?.permissionGranted = (state == .granted)
                        if state == .denied {
                            self?.showPermissionAlert = true
                        }
                        print("📝 Permission request result: \(state)")
                    }
                    .store(in: &cancellables)
            }

            AppLogger.app.info(
                "Screen recording permission: \(self.permissionGranted ? "granted" : "denied")")
        }
    }

    private func loadAvailableDisplays() {
        #if os(macOS)
            var displayCount: UInt32 = 0
            CGGetActiveDisplayList(0, nil, &displayCount)

            var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
            CGGetActiveDisplayList(displayCount, &displays, &displayCount)

            displayIds = displays

            availableDisplays = displays.map { displayId in
                if CGDisplayIsMain(displayId) != 0 {
                    return "Main Display (\(displayId))"
                } else {
                    return "Display \(displayId)"
                }
            }

            if selectedDisplay == nil, let first = availableDisplays.first {
                selectedDisplay = first
                selectedDisplayId = displayIds.first
            }
        #endif
    }

    private func startRecording() {
        guard permissionGranted else {
            print("❌ Permission not granted")
            showPermissionAlert = true
            return
        }

        guard !isRecording else {
            print("❌ Already recording")
            return
        }

        // Get display ID, fallback to main display
        var displayId = selectedDisplayId
        if displayId == nil {
            displayId = CGMainDisplayID()
            print("⚠️ No display selected, using main display: \(displayId!)")
        }
        guard let finalDisplayId = displayId else {
            print("❌ No display available")
            errorMessage = "No display available"
            return
        }

        print("🎬 Starting recording on display \(finalDisplayId)")
        AppLogger.recording.info("Starting recording on display \(finalDisplayId)")

        // Initialize recording manager if needed
        if recordingManager == nil {
            recordingManager = RecordingManager()
        }

        // Configure cinematic effects
        recordingManager?.cinematicEnabled = autoZoom

        // Get display bounds for capture rect
        let displayBounds = CGDisplayBounds(finalDisplayId)
        print("📐 Display bounds: \(displayBounds)")

        // Start actual recording
        recordingManager?.startRecording(displayId: finalDisplayId, captureRect: displayBounds)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                switch completion {
                case .failure(let error):
                    print("❌ Recording failed: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    self?.isRecording = false
                    AppLogger.recording.error("Recording failed: \(error.localizedDescription)")
                case .finished:
                    print("✅ Recording pipeline finished")
                }
            } receiveValue: { _ in
                print("✅ Recording started successfully!")
                AppLogger.recording.info("Recording started successfully")
            }
            .store(in: &cancellables)

        // Update UI immediately for responsiveness
        isRecording = true
        recordingStartTime = Date()
        startTimer()
    }

    private func stopRecording() {
        guard isRecording else {
            print("⚠️ stopRecording called but not recording")
            return
        }

        print("🛑 Stopping recording...")
        AppLogger.recording.info("Stopping recording")

        // Set to false FIRST to prevent re-triggering
        isRecording = false
        stopTimer()

        // Stop actual recording
        recordingManager?.stopRecording()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                switch completion {
                case .failure(let error):
                    print("❌ Stop failed: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    AppLogger.recording.error("Stop failed: \(error.localizedDescription)")
                case .finished:
                    print("✅ Stop pipeline finished")
                }
            } receiveValue: { outputURL in
                print("💾 Recording saved to: \(outputURL.path)")
                AppLogger.recording.info("Recording saved to: \(outputURL.lastPathComponent)")
            }
            .store(in: &cancellables)
    }

    private func startTimer() {
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateDuration()
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        recordingDuration = "00:00:00"
    }

    private func updateDuration() {
        guard let startTime = recordingStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60

        recordingDuration = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
