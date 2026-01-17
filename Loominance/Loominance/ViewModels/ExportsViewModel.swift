//
//  ExportsViewModel.swift
//  Loominance
//
//  ViewModel for the Exports view
//

import Combine
import Foundation
import SwiftUI

/// Export job tracking
struct ExportJob: Identifiable {
    let id: UUID
    let recording: LibraryRecording
    let preset: ExportPreset
    var progress: Double
    var phase: ExportPhase
    var outputURL: URL?
    var error: String?

    var isComplete: Bool {
        phase == .complete
    }

    var isFailed: Bool {
        phase == .failed
    }
}

@MainActor
final class ExportsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var recordings: [LibraryRecording] = []
    @Published var exportJobs: [ExportJob] = []
    @Published var selectedRecording: LibraryRecording?
    @Published var selectedPreset: ExportPreset = .twitter
    @Published var isExporting: Bool = false
    @Published var errorMessage: String?

    // MARK: - Services

    private let libraryManager = LibraryManager()
    private let exportService = ExportService()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Available Presets

    let availablePresets: [ExportPreset] = [
        .twitter,
        .instagramSquare,
        .instagramPortrait,
        .tikTok,
        .youTube,
        .linkedin,
    ]

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    // MARK: - Public Methods

    func loadRecordings() {
        libraryManager.fetchRecordings()
            .receive(on: DispatchQueue.main)
            .sink { _ in
            } receiveValue: { [weak self] recordings in
                self?.recordings = recordings.sorted { $0.createdAt > $1.createdAt }
                if self?.selectedRecording == nil, let first = recordings.first {
                    self?.selectedRecording = first
                }
            }
            .store(in: &cancellables)
    }

    func startExport() {
        guard let recording = selectedRecording else {
            errorMessage = "Please select a recording to export"
            return
        }

        let jobId = UUID()
        let job = ExportJob(
            id: jobId,
            recording: recording,
            preset: selectedPreset,
            progress: 0,
            phase: .preparing,
            outputURL: nil,
            error: nil
        )

        exportJobs.insert(job, at: 0)
        isExporting = true

        let config = ExportConfiguration(
            preset: selectedPreset,
            includeWatermark: false,
            quality: 0.85
        )

        // Subscribe to progress updates
        exportService.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.updateJob(
                    id: jobId,
                    progress: progress.progress,
                    phase: progress.phase,
                    outputURL: progress.outputURL
                )
            }
            .store(in: &cancellables)

        exportService.exportToMP4(recordingId: recording.id, configuration: config, outputURL: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.updateJob(id: jobId, phase: .failed, error: error.localizedDescription)
                }
                self?.isExporting = false
            } receiveValue: { [weak self] progress in
                self?.updateJob(
                    id: jobId,
                    progress: progress.progress,
                    phase: progress.phase,
                    outputURL: progress.outputURL
                )
            }
            .store(in: &cancellables)
    }

    func cancelExport(_ job: ExportJob) {
        exportService.cancelExport()
        updateJob(id: job.id, phase: .cancelled)
    }

    func openExportedFile(_ job: ExportJob) {
        guard let url = job.outputURL else { return }
        NSWorkspace.shared.open(url)
    }

    func showInFinder(_ job: ExportJob) {
        guard let url = job.outputURL else { return }
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }

    func removeJob(_ job: ExportJob) {
        exportJobs.removeAll { $0.id == job.id }
    }

    func presetDescription(_ preset: ExportPreset) -> String {
        let size = preset.resolution
        return "\(Int(size.width))×\(Int(size.height)), MP4"
    }

    func presetIcon(_ preset: ExportPreset) -> String {
        switch preset {
        case .twitter:
            return "bird"
        case .instagramSquare, .instagramPortrait:
            return "camera"
        case .tikTok:
            return "music.note"
        case .youTube:
            return "play.rectangle.fill"
        case .linkedin:
            return "briefcase"
        case .custom:
            return "slider.horizontal.3"
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        libraryManager.libraryPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recordings in
                self?.recordings = recordings.sorted { $0.createdAt > $1.createdAt }
            }
            .store(in: &cancellables)
    }

    private func updateJob(
        id: UUID,
        progress: Double? = nil,
        phase: ExportPhase? = nil,
        outputURL: URL? = nil,
        error: String? = nil
    ) {
        guard let index = exportJobs.firstIndex(where: { $0.id == id }) else { return }

        var job = exportJobs[index]
        if let progress = progress { job.progress = progress }
        if let phase = phase { job.phase = phase }
        if let outputURL = outputURL { job.outputURL = outputURL }
        if let error = error { job.error = error }
        exportJobs[index] = job
    }
}
