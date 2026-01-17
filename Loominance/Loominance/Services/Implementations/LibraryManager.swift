//
//  LibraryManager.swift
//  Loominance
//
//  Manages local recording library with SwiftData
//

import AVFoundation
import AppKit
import Combine
import CoreGraphics
import Foundation
import SwiftData

/// Default implementation of LibraryManager
final class LibraryManager: LibraryManagerProtocol, ObservableObject {

    // MARK: - Properties

    @Published private var recordings: [LibraryRecording] = []

    private let librarySubject = CurrentValueSubject<[LibraryRecording], Never>([])
    var libraryPublisher: AnyPublisher<[LibraryRecording], Never> {
        librarySubject.eraseToAnyPublisher()
    }

    private let storageSubject = CurrentValueSubject<LibraryStorageInfo, Never>(
        LibraryStorageInfo(totalUsed: 0, quota: 10 * 1024 * 1024 * 1024, recordingCount: 0)
    )
    var storagePublisher: AnyPublisher<LibraryStorageInfo, Never> {
        storageSubject.eraseToAnyPublisher()
    }

    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?

    // Storage paths
    private let recordingsDirectory: URL
    private let thumbnailsDirectory: URL

    // MARK: - Initialization

    init() {
        // Set up directories
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let loominanceDir = appSupport.appendingPathComponent("Loominance")

        recordingsDirectory = loominanceDir.appendingPathComponent("Recordings")
        thumbnailsDirectory = loominanceDir.appendingPathComponent("Thumbnails")

        // Create directories
        try? FileManager.default.createDirectory(
            at: recordingsDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(
            at: thumbnailsDirectory, withIntermediateDirectories: true)

        AppLogger.library.info("LibraryManager initialized")
    }

    // MARK: - LibraryManagerProtocol

    func saveRecording(
        url: URL,
        duration: TimeInterval,
        metadata: RecordingMetadata
    ) -> AnyPublisher<LibraryRecording, LibraryError> {

        return Future<LibraryRecording, LibraryError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.saveFailed(reason: "Service deallocated")))
                return
            }

            do {
                // Generate unique filename
                let recordingId = UUID()
                let fileName = "\(recordingId.uuidString).mp4"
                let destinationURL = self.recordingsDirectory.appendingPathComponent(fileName)

                // Copy file to library
                try FileManager.default.copyItem(at: url, to: destinationURL)

                // Get file size
                let attributes = try FileManager.default.attributesOfItem(
                    atPath: destinationURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0

                // Create recording entry
                let recording = LibraryRecording(
                    id: recordingId,
                    fileName: fileName,
                    duration: duration,
                    createdAt: Date(),
                    fileURL: destinationURL,
                    thumbnailURL: nil,
                    fileSize: fileSize,
                    metadata: metadata,
                    exportConfigurations: []
                )

                // Add to library
                self.recordings.append(recording)
                self.librarySubject.send(self.recordings)

                // Update storage info
                self.updateStorageInfo()

                AppLogger.library.info("Recording saved: \(fileName)")
                promise(.success(recording))

            } catch {
                AppLogger.library.error("Failed to save recording: \(error.localizedDescription)")
                promise(.failure(.saveFailed(reason: error.localizedDescription)))
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchRecordings() -> AnyPublisher<[LibraryRecording], LibraryError> {
        return Future<[LibraryRecording], LibraryError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.saveFailed(reason: "Service deallocated")))
                return
            }

            // Scan recordings directory
            do {
                let files = try FileManager.default.contentsOfDirectory(
                    at: self.recordingsDirectory,
                    includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
                )

                var loadedRecordings: [LibraryRecording] = []

                for file in files where file.pathExtension == "mp4" {
                    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    let createdAt = attributes[.creationDate] as? Date ?? Date()

                    let recording = LibraryRecording(
                        id: UUID(),
                        fileName: file.lastPathComponent,
                        duration: 0,  // Would need to read from video
                        createdAt: createdAt,
                        fileURL: file,
                        thumbnailURL: nil,
                        fileSize: fileSize,
                        metadata: RecordingMetadata(
                            resolution: CGSize(width: 1920, height: 1080),
                            frameRate: 60
                        ),
                        exportConfigurations: []
                    )

                    loadedRecordings.append(recording)
                }

                self.recordings = loadedRecordings
                self.librarySubject.send(loadedRecordings)
                self.updateStorageInfo()

                promise(.success(loadedRecordings))

            } catch {
                AppLogger.library.error("Failed to fetch recordings: \(error.localizedDescription)")
                promise(.failure(.saveFailed(reason: error.localizedDescription)))
            }
        }
        .eraseToAnyPublisher()
    }

    func getRecording(id: UUID) -> LibraryRecording? {
        return recordings.first { $0.id == id }
    }

    func updateRecording(id: UUID, metadata: RecordingMetadata) -> AnyPublisher<
        LibraryRecording, LibraryError
    > {
        return Future<LibraryRecording, LibraryError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.saveFailed(reason: "Service deallocated")))
                return
            }

            guard let index = self.recordings.firstIndex(where: { $0.id == id }) else {
                promise(.failure(.recordingNotFound(id: id)))
                return
            }

            var recording = self.recordings[index]
            let updatedRecording = LibraryRecording(
                id: recording.id,
                fileName: recording.fileName,
                duration: recording.duration,
                createdAt: recording.createdAt,
                fileURL: recording.fileURL,
                thumbnailURL: recording.thumbnailURL,
                fileSize: recording.fileSize,
                metadata: metadata,
                exportConfigurations: recording.exportConfigurations
            )

            self.recordings[index] = updatedRecording
            self.librarySubject.send(self.recordings)

            promise(.success(updatedRecording))
        }
        .eraseToAnyPublisher()
    }

    func deleteRecording(id: UUID) -> AnyPublisher<Void, LibraryError> {
        return Future<Void, LibraryError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.saveFailed(reason: "Service deallocated")))
                return
            }

            guard let recording = self.recordings.first(where: { $0.id == id }) else {
                promise(.failure(.recordingNotFound(id: id)))
                return
            }

            do {
                // Delete file
                try FileManager.default.removeItem(at: recording.fileURL)

                // Delete thumbnail if exists
                if let thumbnailURL = recording.thumbnailURL {
                    try? FileManager.default.removeItem(at: thumbnailURL)
                }

                // Remove from list
                self.recordings.removeAll { $0.id == id }
                self.librarySubject.send(self.recordings)
                self.updateStorageInfo()

                AppLogger.library.info("Recording deleted: \(recording.fileName)")
                promise(.success(()))

            } catch {
                AppLogger.library.error("Failed to delete recording: \(error.localizedDescription)")
                promise(.failure(.deleteFailed(reason: error.localizedDescription)))
            }
        }
        .eraseToAnyPublisher()
    }

    func deleteRecordings(ids: [UUID]) -> AnyPublisher<Void, LibraryError> {
        let publishers = ids.map { deleteRecording(id: $0) }
        return Publishers.MergeMany(publishers)
            .collect()
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func searchRecordings(query: String) -> AnyPublisher<[LibraryRecording], LibraryError> {
        return Just(
            recordings.filter { recording in
                if query.isEmpty { return true }
                let queryLower = query.lowercased()
                return recording.fileName.lowercased().contains(queryLower)
                    || recording.metadata.title?.lowercased().contains(queryLower) == true
                    || recording.metadata.tags.contains { $0.lowercased().contains(queryLower) }
            }
        )
        .setFailureType(to: LibraryError.self)
        .eraseToAnyPublisher()
    }

    func getStorageInfo() -> LibraryStorageInfo {
        return storageSubject.value
    }

    func cleanupOldRecordings(targetBytes: Int64) -> AnyPublisher<Int64, LibraryError> {
        return Future<Int64, LibraryError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.saveFailed(reason: "Service deallocated")))
                return
            }

            var freedBytes: Int64 = 0
            let sortedRecordings = self.recordings.sorted { $0.createdAt < $1.createdAt }

            for recording in sortedRecordings {
                if freedBytes >= targetBytes {
                    break
                }

                do {
                    try FileManager.default.removeItem(at: recording.fileURL)
                    freedBytes += recording.fileSize
                    self.recordings.removeAll { $0.id == recording.id }

                    AppLogger.library.info(
                        "Cleaned up: \(recording.fileName) (\(recording.fileSize) bytes)")
                } catch {
                    AppLogger.library.warning(
                        "Failed to clean up: \(error.localizedDescription)")
                }
            }

            self.librarySubject.send(self.recordings)
            self.updateStorageInfo()

            promise(.success(freedBytes))
        }
        .eraseToAnyPublisher()
    }

    func generateThumbnail(for id: UUID) -> AnyPublisher<URL, LibraryError> {
        return Future<URL, LibraryError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.saveFailed(reason: "Service deallocated")))
                return
            }

            guard let recording = self.recordings.first(where: { $0.id == id }) else {
                promise(.failure(.recordingNotFound(id: id)))
                return
            }

            // Generate thumbnail using AVAssetImageGenerator
            let asset = AVAsset(url: recording.fileURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true

            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            let thumbnailURL = self.thumbnailsDirectory.appendingPathComponent(
                "\(id.uuidString).jpg")

            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: 320, height: 180))

                if let tiffData = nsImage.tiffRepresentation,
                    let bitmap = NSBitmapImageRep(data: tiffData),
                    let jpegData = bitmap.representation(using: .jpeg, properties: [:])
                {
                    try jpegData.write(to: thumbnailURL)
                    AppLogger.library.info("Thumbnail generated: \(thumbnailURL.lastPathComponent)")
                    promise(.success(thumbnailURL))
                } else {
                    promise(.failure(.thumbnailGenerationFailed))
                }
            } catch {
                AppLogger.library.error(
                    "Thumbnail generation failed: \(error.localizedDescription)")
                promise(.failure(.thumbnailGenerationFailed))
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Private Methods

    private func updateStorageInfo() {
        let totalUsed = recordings.reduce(0) { $0 + $1.fileSize }
        let quota: Int64 = 10 * 1024 * 1024 * 1024  // 10 GB

        let info = LibraryStorageInfo(
            totalUsed: totalUsed,
            quota: quota,
            recordingCount: recordings.count
        )

        storageSubject.send(info)
    }
}
