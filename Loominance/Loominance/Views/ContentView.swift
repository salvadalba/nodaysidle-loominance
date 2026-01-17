//
//  ContentView.swift
//  Loominance
//
//  Main content view with native macOS dark design
//

import SwiftUI

#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var selectedTab: TabSelection = .record
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    // Dark theme colors
    private let backgroundColor = Color(red: 0.11, green: 0.11, blue: 0.12)
    private let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.15)
    private let borderColor = Color(red: 0.22, green: 0.22, blue: 0.24)
    private let subtleText = Color(red: 0.55, green: 0.55, blue: 0.58)

    var body: some View {
        ZStack {
            // Dark background
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                navigationBar

                // Main content
                mainContent
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.onAppear()
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack(spacing: 16) {
            // App title with icon
            HStack(spacing: 8) {
                Image(systemName: "record.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)

                Text("Loominance")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }

            Spacer()

            // Tab picker with custom styling
            HStack(spacing: 2) {
                ForEach(TabSelection.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.caption)
                            Text(tab.title)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedTab == tab ? cardBackground : Color.clear)
                        )
                        .foregroundColor(selectedTab == tab ? .white : subtleText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )

            Spacer()

            // Settings button
            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(subtleText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .fill(borderColor)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch selectedTab {
        case .record:
            RecordingView(viewModel: viewModel)
        case .library:
            LibraryView()
        case .exports:
            ExportsView()
        }
    }
}

// MARK: - Tab Selection

enum TabSelection: String, CaseIterable {
    case record = "Record"
    case library = "Library"
    case exports = "Exports"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .record: return "record.circle"
        case .library: return "photo.stack"
        case .exports: return "square.and.arrow.up"
        }
    }
}

// MARK: - Recording View

struct RecordingView: View {
    @ObservedObject var viewModel: MainViewModel

    // Dark theme colors
    private let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.15)
    private let borderColor = Color(red: 0.22, green: 0.22, blue: 0.24)
    private let subtleText = Color(red: 0.55, green: 0.55, blue: 0.58)

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Preview area
            previewArea

            Spacer()

            // Recording controls
            recordingControls
        }
    }

    private var previewArea: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: viewModel.isRecording ? "record.circle.fill" : "display")
                        .font(.system(size: 48))
                        .foregroundStyle(viewModel.isRecording ? .red : subtleText)

                    Text(viewModel.isRecording ? "Recording..." : "Ready to Record")
                        .font(.headline)
                        .foregroundStyle(subtleText)

                    if viewModel.isRecording {
                        Text(viewModel.recordingDuration)
                            .font(.system(size: 48, weight: .light, design: .monospaced))
                            .foregroundStyle(.red)
                    } else {
                        Text("Press the record button or ⌘R to start")
                            .font(.subheadline)
                            .foregroundStyle(subtleText.opacity(0.6))
                    }
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
    }

    private var recordingControls: some View {
        HStack(spacing: 24) {
            // Display selector
            displaySelector

            Spacer()

            // Record button
            recordButton

            Spacer()

            // Options
            optionsMenu
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
    }

    private var displaySelector: some View {
        Menu {
            ForEach(viewModel.availableDisplays, id: \.self) { display in
                Button(display) {
                    viewModel.selectDisplay(display)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "display")
                Text(viewModel.selectedDisplay ?? "Select Display")
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.18, green: 0.18, blue: 0.20))
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var recordButton: some View {
        Button {
            viewModel.toggleRecording()
        } label: {
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : Color.red.opacity(0.9))
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: .red.opacity(viewModel.isRecording ? 0.4 : 0.2), radius: 8, x: 0,
                        y: 2)

                if viewModel.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 18, height: 18)
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                }
            }
            .scaleEffect(viewModel.isRecording ? 1.05 : 1.0)
            .animation(
                viewModel.isRecording
                    ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: viewModel.isRecording
            )
        }
        .buttonStyle(.plain)
        .help(viewModel.isRecording ? "Stop Recording (⇧⌘R)" : "Start Recording (⌘R)")
    }

    private var optionsMenu: some View {
        Menu {
            Toggle("Show Cursor", isOn: $viewModel.showCursor)
            Toggle("Auto Zoom", isOn: $viewModel.autoZoom)
            Divider()
            Menu("Zoom Intensity") {
                ForEach([1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { level in
                    Button {
                        viewModel.zoomIntensity = Float(level)
                    } label: {
                        HStack {
                            Text("\(level, specifier: "%.2f")x")
                            if viewModel.zoomIntensity == Float(level) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                Text("Options")
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.18, green: 0.18, blue: 0.20))
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

// MARK: - Library View

struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var selectedRecording: LibraryRecording?

    private let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.15)
    private let borderColor = Color(red: 0.22, green: 0.22, blue: 0.24)
    private let subtleText = Color(red: 0.55, green: 0.55, blue: 0.58)

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Toolbar
            libraryToolbar

            // Content
            if viewModel.isLoading {
                loadingView
            } else if viewModel.recordings.isEmpty {
                emptyState
            } else {
                recordingsGrid
            }
        }
        .onAppear {
            viewModel.loadRecordings()
        }
    }

    func playRecording(_ recording: LibraryRecording) {
        // Just open in Finder for now - simplest solution
        NSWorkspace.shared.open(recording.fileURL)
    }

    // MARK: - Toolbar

    private var libraryToolbar: some View {
        HStack {
            Text("Library")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("(\(viewModel.recordings.count))")
                .font(.subheadline)
                .foregroundStyle(subtleText)

            Spacer()

            Button {
                viewModel.loadRecordings()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .help("Refresh Library")

            Button {
                if let firstRecording = viewModel.recordings.first {
                    viewModel.openInFinder(firstRecording)
                } else {
                    // Open recordings folder
                    let appSupport = FileManager.default.urls(
                        for: .applicationSupportDirectory, in: .userDomainMask
                    ).first!
                    let recordingsDir = appSupport.appendingPathComponent("Loominance/Recordings")
                    NSWorkspace.shared.open(recordingsDir)
                }
            } label: {
                Label("Open Folder", systemImage: "folder")
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 8)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading recordings...")
                .font(.subheadline)
                .foregroundStyle(subtleText)
                .padding(.top, 12)
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 48))
                    .foregroundStyle(subtleText)

                Text("No Recordings Yet")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Your recordings will appear here after you record your first clip.")
                    .font(.subheadline)
                    .foregroundStyle(subtleText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            Spacer()
        }
    }

    // MARK: - Recordings Grid

    private var recordingsGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.recordings, id: \.id) { recording in
                    RecordingCard(
                        recording: recording,
                        thumbnail: viewModel.thumbnails[recording.id],
                        viewModel: viewModel,
                        onPlay: {
                            playRecording(recording)
                        }
                    )
                }
            }
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Recording Card

struct RecordingCard: View {
    let recording: LibraryRecording
    let thumbnail: NSImage?
    @ObservedObject var viewModel: LibraryViewModel
    let onPlay: () -> Void

    @State private var isHovering = false

    private let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.15)
    private let borderColor = Color(red: 0.22, green: 0.22, blue: 0.24)
    private let subtleText = Color(red: 0.55, green: 0.55, blue: 0.58)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            thumbnailView
                .frame(height: 140)
                .clipped()

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(recording.fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    // Date
                    Label(viewModel.formatDate(recording.createdAt), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(subtleText)

                    Spacer()

                    // Size
                    Text(viewModel.formatFileSize(recording.fileSize))
                        .font(.caption)
                        .foregroundStyle(subtleText)
                }
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovering ? Color.white.opacity(0.2) : borderColor, lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(count: 2) {
            onPlay()
        }
        .contextMenu {
            Button {
                onPlay()
            } label: {
                Label("Play", systemImage: "play.fill")
            }

            Button {
                viewModel.openInFinder(recording)
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }

            Divider()

            Button(role: .destructive) {
                viewModel.deleteRecording(recording)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color.black.opacity(0.5))

            // Thumbnail or placeholder
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "video.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(subtleText)
            }

            // Play overlay on hover
            if isHovering {
                Color.black.opacity(0.3)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Exports View

struct ExportsView: View {
    @StateObject private var viewModel = ExportsViewModel()

    private let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.15)
    private let borderColor = Color(red: 0.22, green: 0.22, blue: 0.24)
    private let subtleText = Color(red: 0.55, green: 0.55, blue: 0.58)

    var body: some View {
        VStack(spacing: 16) {
            // Toolbar
            HStack {
                Text("Exports")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.top, 8)

            HStack(spacing: 20) {
                // Left side: Export options
                exportOptionsPanel
                    .frame(maxWidth: 300)

                // Right side: Export jobs
                exportJobsPanel
            }
        }
        .onAppear {
            viewModel.loadRecordings()
        }
    }

    // MARK: - Export Options Panel

    private var exportOptionsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Recording selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Recording")
                    .font(.subheadline)
                    .foregroundStyle(subtleText)

                Picker("Recording", selection: $viewModel.selectedRecording) {
                    Text("Select...").tag(nil as LibraryRecording?)
                    ForEach(viewModel.recordings, id: \.id) { recording in
                        Text(recording.fileName).tag(recording as LibraryRecording?)
                    }
                }
                .labelsHidden()
            }

            // Preset selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Export Preset")
                    .font(.subheadline)
                    .foregroundStyle(subtleText)

                ForEach(viewModel.availablePresets, id: \.self) { preset in
                    PresetButton(
                        preset: preset,
                        isSelected: viewModel.selectedPreset == preset,
                        description: viewModel.presetDescription(preset)
                    ) {
                        viewModel.selectedPreset = preset
                    }
                }
            }

            Spacer()

            // Export button
            Button {
                viewModel.startExport()
            } label: {
                HStack {
                    if viewModel.isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(viewModel.isExporting ? "Exporting..." : "Export")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(viewModel.selectedRecording == nil || viewModel.isExporting)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    // MARK: - Export Jobs Panel

    private var exportJobsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export History")
                .font(.subheadline)
                .foregroundStyle(subtleText)

            if viewModel.exportJobs.isEmpty {
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 32))
                            .foregroundStyle(subtleText)
                        Text("No exports yet")
                            .font(.subheadline)
                            .foregroundStyle(subtleText)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.exportJobs) { job in
                            ExportJobRow(job: job, viewModel: viewModel)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let preset: ExportPreset
    let isSelected: Bool
    let description: String
    let action: () -> Void

    private let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.15)
    private let borderColor = Color(red: 0.22, green: 0.22, blue: 0.24)
    private let subtleText = Color(red: 0.55, green: 0.55, blue: 0.58)

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: presetIcon)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(subtleText)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.red.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.red.opacity(0.5) : borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
    }

    private var presetIcon: String {
        switch preset {
        case .twitter: return "bird"
        case .instagramSquare, .instagramPortrait: return "camera"
        case .tikTok: return "music.note"
        case .youTube: return "play.rectangle.fill"
        case .linkedin: return "briefcase"
        case .custom: return "slider.horizontal.3"
        }
    }
}

// MARK: - Export Job Row

struct ExportJobRow: View {
    let job: ExportJob
    @ObservedObject var viewModel: ExportsViewModel

    private let subtleText = Color(red: 0.55, green: 0.55, blue: 0.58)
    private let borderColor = Color(red: 0.22, green: 0.22, blue: 0.24)

    var body: some View {
        HStack {
            // Status icon
            statusIcon
                .frame(width: 24)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(job.recording.fileName)
                    .font(.subheadline)
                    .lineLimit(1)

                if job.isComplete {
                    Text("Completed • \(job.preset.rawValue)")
                        .font(.caption)
                        .foregroundStyle(subtleText)
                } else if job.isFailed {
                    Text(job.error ?? "Export failed")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("\(Int(job.progress * 100))% • \(job.phase.description)")
                        .font(.caption)
                        .foregroundStyle(subtleText)
                }
            }

            Spacer()

            // Actions
            if job.isComplete {
                Button {
                    viewModel.openExportedFile(job)
                } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(subtleText)

                Button {
                    viewModel.showInFinder(job)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.plain)
                .foregroundStyle(subtleText)
            } else if !job.isFailed {
                ProgressView(value: job.progress)
                    .frame(width: 60)
            }

            Button {
                viewModel.removeJob(job)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(subtleText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        if job.isComplete {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else if job.isFailed {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        } else {
            Image(systemName: "arrow.up.circle")
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            RecordingSettingsView()
                .tabItem {
                    Label("Recording", systemImage: "record.circle")
                }

            ExportSettingsView()
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

            StorageSettingsView()
                .tabItem {
                    Label("Storage", systemImage: "internaldrive")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("showOnboarding") private var showOnboarding = true
    @AppStorage("globalShortcuts") private var globalShortcuts = true

    var body: some View {
        Form {
            Section {
                Toggle("Show onboarding on launch", isOn: $showOnboarding)
                Toggle("Enable global keyboard shortcuts", isOn: $globalShortcuts)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct RecordingSettingsView: View {
    @AppStorage("showCursor") private var showCursor = true
    @AppStorage("autoZoom") private var autoZoom = false
    @AppStorage("zoomIntensity") private var zoomIntensity = 1.5

    var body: some View {
        Form {
            Section("Cursor") {
                Toggle("Show cursor in recording", isOn: $showCursor)
            }

            Section("Cinematic Zoom") {
                Toggle("Enable auto zoom", isOn: $autoZoom)
                Slider(value: $zoomIntensity, in: 1.0...2.0, step: 0.25) {
                    Text("Zoom intensity: \(zoomIntensity, specifier: "%.2f")x")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ExportSettingsView: View {
    @AppStorage("defaultPreset") private var defaultPreset = "Twitter (16:9)"
    @AppStorage("includeWatermark") private var includeWatermark = false

    var body: some View {
        Form {
            Section("Default Export Settings") {
                Picker("Default preset", selection: $defaultPreset) {
                    Text("Twitter (16:9)").tag("Twitter (16:9)")
                    Text("Instagram (Square 1:1)").tag("Instagram (Square 1:1)")
                    Text("TikTok (9:16)").tag("TikTok (9:16)")
                    Text("YouTube (16:9)").tag("YouTube (16:9)")
                }

                Toggle("Include watermark", isOn: $includeWatermark)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct StorageSettingsView: View {
    @AppStorage("autoCleanup") private var autoCleanup = false

    var body: some View {
        Form {
            Section("Storage") {
                LabeledContent("Location") {
                    Text("~/Library/Application Support/Loominance")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Used") {
                    Text("0 MB")
                        .foregroundStyle(.secondary)
                }

                Toggle("Auto cleanup old recordings", isOn: $autoCleanup)
            }

            Section {
                Button("Open in Finder") {
                    if let url = FileManager.default.urls(
                        for: .applicationSupportDirectory, in: .userDomainMask
                    ).first?.appendingPathComponent("Loominance") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
