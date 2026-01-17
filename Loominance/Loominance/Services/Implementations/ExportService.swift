//
//  ExportService.swift
//  Loominance
//
//  Video export service using AVAssetExportSession
//

import AVFoundation
import Combine
import CoreGraphics
import Foundation

/// Default implementation of ExportService
final class ExportService: ExportServiceProtocol {

    // MARK: - Properties

    private(set) var currentExport: UUID?

    private let progressSubject = PassthroughSubject<ExportProgress, Never>()
    var progressPublisher: AnyPublisher<ExportProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    private var exportSession: AVAssetExportSession?
    private var progressTimer: Timer?
    private var isCancelled = false

    private let exportQueue = DispatchQueue(label: "com.loominance.export", qos: .userInitiated)
    private let libraryManager = LibraryManager()

    // MARK: - ExportServiceProtocol

    func exportToMP4(
        recordingId: UUID,
        configuration: ExportConfiguration,
        outputURL: URL?
    ) -> AnyPublisher<ExportProgress, ExportError> {

        guard currentExport == nil else {
            return Fail(error: ExportError.exportInProgress).eraseToAnyPublisher()
        }

        // Validate configuration
        if case .failure(let error) = validateConfiguration(configuration) {
            return Fail(error: error).eraseToAnyPublisher()
        }

        currentExport = recordingId
        isCancelled = false

        let finalOutputURL =
            outputURL ?? generateOutputURL(for: recordingId, preset: configuration.preset)

        return Future<ExportProgress, ExportError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.encodingFailed(reason: "Service deallocated")))
                return
            }

            // Get source recording URL from library
            guard let recording = self.libraryManager.getRecording(id: recordingId) else {
                self.currentExport = nil
                promise(
                    .failure(.fileNotFound(url: URL(fileURLWithPath: "/recording/\(recordingId)"))))
                return
            }

            let sourceURL = recording.fileURL

            // Send preparing progress
            let preparingProgress = ExportProgress(
                recordingId: recordingId,
                progress: 0.0,
                estimatedTimeRemaining: nil,
                phase: .preparing,
                outputURL: nil
            )
            self.progressSubject.send(preparingProgress)

            self.exportQueue.async {
                self.performExport(
                    sourceURL: sourceURL,
                    outputURL: finalOutputURL,
                    recordingId: recordingId,
                    configuration: configuration,
                    promise: promise
                )
            }
        }
        .eraseToAnyPublisher()
    }

    func cancelExport() {
        isCancelled = true
        exportSession?.cancelExport()
        progressTimer?.invalidate()
        progressTimer = nil
        currentExport = nil

        AppLogger.export.info("Export cancelled")
    }

    func availablePresets() -> [ExportPreset] {
        return ExportPreset.allCases
    }

    func validateConfiguration(_ configuration: ExportConfiguration) -> Result<Void, ExportError> {
        if configuration.quality < 0 || configuration.quality > 1.0 {
            return .failure(.invalidPreset(reason: "Quality must be between 0 and 1"))
        }

        if configuration.frameRate < 1 || configuration.frameRate > 120 {
            return .failure(.invalidPreset(reason: "Invalid frame rate"))
        }

        return .success(())
    }

    // MARK: - Private Methods

    private func performExport(
        sourceURL: URL,
        outputURL: URL,
        recordingId: UUID,
        configuration: ExportConfiguration,
        promise: @escaping (Result<ExportProgress, ExportError>) -> Void
    ) {
        // Remove existing file at output URL
        try? FileManager.default.removeItem(at: outputURL)

        // Create source asset
        let asset = AVURLAsset(url: sourceURL)

        // Determine export preset based on configuration
        let presetName = selectAVPreset(for: configuration)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: presetName) else {
            AppLogger.export.error("Failed to create export session")
            DispatchQueue.main.async {
                self.currentExport = nil
                promise(.failure(.encodingFailed(reason: "Failed to create export session")))
            }
            return
        }

        self.exportSession = exportSession

        // Configure export session
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        // Apply video composition for resizing if needed
        if configuration.preset != .custom {
            let videoComposition = createVideoComposition(
                for: asset,
                targetSize: configuration.outputSize
            )
            exportSession.videoComposition = videoComposition
        }

        AppLogger.export.info(
            "Starting export: \(sourceURL.lastPathComponent) -> \(outputURL.lastPathComponent)"
        )

        // Start progress monitoring
        DispatchQueue.main.async {
            self.startProgressMonitoring(recordingId: recordingId, outputURL: outputURL)
        }

        // Start export
        exportSession.exportAsynchronously { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.progressTimer?.invalidate()
                self.progressTimer = nil
            }

            switch exportSession.status {
            case .completed:
                let finalProgress = ExportProgress(
                    recordingId: recordingId,
                    progress: 1.0,
                    estimatedTimeRemaining: 0,
                    phase: .complete,
                    outputURL: outputURL
                )

                DispatchQueue.main.async {
                    self.progressSubject.send(finalProgress)
                    self.currentExport = nil
                    AppLogger.export.info("Export completed: \(outputURL.lastPathComponent)")
                    promise(.success(finalProgress))
                }

            case .cancelled:
                let cancelledProgress = ExportProgress(
                    recordingId: recordingId,
                    progress: Double(exportSession.progress),
                    estimatedTimeRemaining: nil,
                    phase: .cancelled,
                    outputURL: nil
                )

                DispatchQueue.main.async {
                    self.progressSubject.send(cancelledProgress)
                    self.currentExport = nil
                    promise(.failure(.cancelled))
                }

            case .failed:
                let errorMessage = exportSession.error?.localizedDescription ?? "Unknown error"
                AppLogger.export.error("Export failed: \(errorMessage)")

                DispatchQueue.main.async {
                    self.currentExport = nil
                    promise(.failure(.encodingFailed(reason: errorMessage)))
                }

            default:
                break
            }
        }
    }

    private func startProgressMonitoring(recordingId: UUID, outputURL: URL) {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            guard let self = self,
                let session = self.exportSession
            else {
                return
            }

            let progress = Double(session.progress)
            let phase: ExportPhase = progress < 0.9 ? .encoding : .finalizing

            let currentProgress = ExportProgress(
                recordingId: recordingId,
                progress: progress,
                estimatedTimeRemaining: nil,
                phase: phase,
                outputURL: nil
            )

            self.progressSubject.send(currentProgress)
        }
    }

    private func selectAVPreset(for configuration: ExportConfiguration) -> String {
        // Select appropriate AVAssetExportSession preset based on target resolution
        let targetHeight = Int(configuration.outputSize.height)

        if targetHeight >= 2160 {
            return AVAssetExportPreset3840x2160
        } else if targetHeight >= 1080 {
            return AVAssetExportPreset1920x1080
        } else if targetHeight >= 720 {
            return AVAssetExportPreset1280x720
        } else {
            return AVAssetExportPreset960x540
        }
    }

    private func createVideoComposition(for asset: AVAsset, targetSize: CGSize)
        -> AVVideoComposition?
    {
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return nil
        }

        let naturalSize = videoTrack.naturalSize
        let transform = videoTrack.preferredTransform

        // Apply transform to get actual video size
        let isPortrait = transform.a == 0 && transform.d == 0
        let videoSize =
            isPortrait
            ? CGSize(width: naturalSize.height, height: naturalSize.width)
            : naturalSize

        // Calculate scale to fit target size while maintaining aspect ratio
        let scaleX = targetSize.width / videoSize.width
        let scaleY = targetSize.height / videoSize.height
        let scale = min(scaleX, scaleY)

        let scaledWidth = videoSize.width * scale
        let scaledHeight = videoSize.height * scale

        // Center the video in the target frame
        let offsetX = (targetSize.width - scaledWidth) / 2
        let offsetY = (targetSize.height - scaledHeight) / 2

        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        let translateTransform = CGAffineTransform(translationX: offsetX, y: offsetY)
        let finalTransform = scaleTransform.concatenating(translateTransform)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(finalTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = targetSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = [instruction]

        return videoComposition
    }

    private func generateOutputURL(for recordingId: UUID, preset: ExportPreset) -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        let presetSuffix = preset.rawValue.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: ":", with: "")

        let fileName = "Loominance_\(timestamp)_\(presetSuffix).mp4"

        let documentsURL = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let exportsURL = documentsURL.appendingPathComponent("Loominance/Exports")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: exportsURL, withIntermediateDirectories: true)

        return exportsURL.appendingPathComponent(fileName)
    }
}
