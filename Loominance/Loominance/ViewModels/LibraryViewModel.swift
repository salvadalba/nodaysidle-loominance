//
//  LibraryViewModel.swift
//  Loominance
//
//  ViewModel for the Library view
//

import AVFoundation
import Combine
import Foundation
import SwiftUI

@MainActor
final class LibraryViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var recordings: [LibraryRecording] = []
    @Published var isLoading: Bool = false
    @Published var selectedRecording: LibraryRecording?
    @Published var thumbnails: [UUID: NSImage] = [:]
    @Published var errorMessage: String?
    @Published var searchQuery: String = ""

    // MARK: - Services

    private let libraryManager = LibraryManager()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    // MARK: - Public Methods

    func loadRecordings() {
        isLoading = true

        libraryManager.fetchRecordings()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] recordings in
                self?.recordings = recordings.sorted { $0.createdAt > $1.createdAt }
                print("📚 Loaded \(recordings.count) recordings")

                // Generate thumbnails for each
                for recording in recordings {
                    self?.generateThumbnail(for: recording)
                }
            }
            .store(in: &cancellables)
    }

    func deleteRecording(_ recording: LibraryRecording) {
        libraryManager.deleteRecording(id: recording.id)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] in
                self?.recordings.removeAll { $0.id == recording.id }
                self?.thumbnails.removeValue(forKey: recording.id)
                print("🗑️ Deleted recording: \(recording.fileName)")
            }
            .store(in: &cancellables)
    }

    func openInFinder(_ recording: LibraryRecording) {
        NSWorkspace.shared.selectFile(recording.fileURL.path, inFileViewerRootedAtPath: "")
    }

    func openRecording(_ recording: LibraryRecording) {
        NSWorkspace.shared.open(recording.fileURL)
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Subscribe to library changes
        libraryManager.libraryPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recordings in
                self?.recordings = recordings.sorted { $0.createdAt > $1.createdAt }
            }
            .store(in: &cancellables)
    }

    private func generateThumbnail(for recording: LibraryRecording) {
        // Generate on background queue
        Task.detached(priority: .background) { [weak self] in
            let asset = AVAsset(url: recording.fileURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 320, height: 180)

            do {
                let time = CMTime(seconds: 0.5, preferredTimescale: 600)
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: 320, height: 180))

                await MainActor.run {
                    self?.thumbnails[recording.id] = nsImage
                }
            } catch {
                print("⚠️ Thumbnail failed for \(recording.fileName): \(error.localizedDescription)")
            }
        }
    }
}
