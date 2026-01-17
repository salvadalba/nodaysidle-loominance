//
//  VideoEncoder.swift
//  Loominance
//
//  Hardware-accelerated video encoding using VideoToolbox
//

import AVFoundation
import Combine
import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

/// Video encoder configuration
struct VideoEncoderConfiguration {
    let width: Int
    let height: Int
    let frameRate: Int32
    let bitRate: Int
    let codec: AVVideoCodecType
    let outputURL: URL

    static func `default`(width: Int, height: Int, outputURL: URL) -> VideoEncoderConfiguration {
        return VideoEncoderConfiguration(
            width: width,
            height: height,
            frameRate: 60,
            bitRate: 10_000_000,  // 10 Mbps
            codec: .h264,
            outputURL: outputURL
        )
    }
}

/// Video encoder state
enum VideoEncoderState: Equatable {
    case idle
    case encoding
    case finalizing
    case complete
    case error(String)
}

/// Hardware-accelerated video encoder
final class VideoEncoder: ObservableObject {

    // MARK: - Properties

    @Published private(set) var state: VideoEncoderState = .idle
    @Published private(set) var frameCount: Int = 0

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private let encoderQueue = DispatchQueue(label: "com.loominance.encoder", qos: .userInitiated)
    private var startTime: CMTime?
    private var configuration: VideoEncoderConfiguration?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Public Methods

    /// Start encoding session
    func startEncoding(configuration: VideoEncoderConfiguration) -> AnyPublisher<Void, ExportError>
    {
        return Future<Void, ExportError> { [weak self] promise in
            self?.encoderQueue.async {
                do {
                    try self?.setupEncoder(configuration: configuration)
                    self?.configuration = configuration

                    DispatchQueue.main.async {
                        self?.state = .encoding
                        self?.frameCount = 0
                    }

                    AppLogger.export.info("Video encoder started")
                    promise(.success(()))
                } catch {
                    AppLogger.export.error("Failed to start encoder: \(error.localizedDescription)")
                    promise(.failure(.encodingFailed(reason: error.localizedDescription)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// Encode a single frame
    func encodeFrame(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        encoderQueue.async { [weak self] in
            guard let self = self,
                let input = self.videoInput,
                let adaptor = self.pixelBufferAdaptor
            else { return }

            // Wait for encoder to be ready
            guard input.isReadyForMoreMediaData else {
                PerformanceMetrics.shared.recordDroppedFrame()
                AppLogger.export.debug("Encoder not ready, dropping frame")
                return
            }

            // Set start time on first frame
            if self.startTime == nil {
                self.startTime = presentationTime
            }

            // Calculate relative time
            let relativeTime = CMTimeSubtract(presentationTime, self.startTime!)

            // Append frame
            let success = adaptor.append(pixelBuffer, withPresentationTime: relativeTime)

            if success {
                DispatchQueue.main.async {
                    self.frameCount += 1
                }
            } else {
                AppLogger.export.warning("Failed to append frame at time \(relativeTime.seconds)")
            }
        }
    }

    /// Finish encoding and save file
    func finishEncoding() -> AnyPublisher<URL, ExportError> {
        return Future<URL, ExportError> { [weak self] promise in
            self?.encoderQueue.async {
                guard let self = self,
                    let writer = self.assetWriter,
                    let config = self.configuration
                else {
                    promise(.failure(.encodingFailed(reason: "No active encoding session")))
                    return
                }

                DispatchQueue.main.async {
                    self.state = .finalizing
                }

                // Mark input as finished
                self.videoInput?.markAsFinished()

                // Finish writing
                writer.finishWriting {
                    if writer.status == .completed {
                        DispatchQueue.main.async {
                            self.state = .complete
                        }

                        AppLogger.export.info(
                            "Video encoding complete: \(self.frameCount) frames, \(config.outputURL.lastPathComponent)"
                        )
                        promise(.success(config.outputURL))
                    } else {
                        let errorMessage =
                            writer.error?.localizedDescription ?? "Unknown error"
                        DispatchQueue.main.async {
                            self.state = .error(errorMessage)
                        }
                        promise(.failure(.encodingFailed(reason: errorMessage)))
                    }
                }

                // Clean up
                self.assetWriter = nil
                self.videoInput = nil
                self.pixelBufferAdaptor = nil
                self.startTime = nil
            }
        }
        .eraseToAnyPublisher()
    }

    /// Cancel encoding
    func cancelEncoding() {
        encoderQueue.async { [weak self] in
            self?.assetWriter?.cancelWriting()
            self?.cleanup()

            DispatchQueue.main.async {
                self?.state = .idle
            }

            AppLogger.export.info("Video encoding cancelled")
        }
    }

    // MARK: - Private Methods

    private func setupEncoder(configuration: VideoEncoderConfiguration) throws {
        // Remove existing file
        try? FileManager.default.removeItem(at: configuration.outputURL)

        // Create asset writer
        let writer = try AVAssetWriter(outputURL: configuration.outputURL, fileType: .mp4)

        // Video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: configuration.codec,
            AVVideoWidthKey: configuration.width,
            AVVideoHeightKey: configuration.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: configuration.bitRate,
                AVVideoExpectedSourceFrameRateKey: configuration.frameRate,
                AVVideoMaxKeyFrameIntervalKey: configuration.frameRate * 2,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoAllowFrameReorderingKey: false,
            ] as [String: Any],
        ]

        // Create input
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true
        input.transform = .identity

        // Create pixel buffer adaptor
        let adaptorAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: configuration.width,
            kCVPixelBufferHeightKey as String: configuration.height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: adaptorAttributes
        )

        // Add input to writer
        guard writer.canAdd(input) else {
            throw ExportError.assetWriterCreationFailed(reason: "Cannot add video input")
        }
        writer.add(input)

        // Start writing
        guard writer.startWriting() else {
            throw ExportError.assetWriterCreationFailed(
                reason: writer.error?.localizedDescription ?? "Unknown error")
        }
        writer.startSession(atSourceTime: .zero)

        // Store references
        self.assetWriter = writer
        self.videoInput = input
        self.pixelBufferAdaptor = adaptor

        AppLogger.export.debug(
            "Encoder configured: \(configuration.width)x\(configuration.height) @ \(configuration.frameRate)fps"
        )
    }

    private func cleanup() {
        assetWriter = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        startTime = nil
        configuration = nil
    }
}
