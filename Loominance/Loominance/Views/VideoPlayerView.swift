//
//  VideoPlayerView.swift
//  Loominance
//
//  In-app video player using AVPlayer
//

import AVFoundation
import AVKit
import Combine
import SwiftUI

struct VideoPlayerView: View {
    let recording: LibraryRecording
    @StateObject private var playerController = VideoPlayerController()

    private let backgroundColor = Color(red: 0.08, green: 0.08, blue: 0.09)
    private let subtleText = Color(red: 0.55, green: 0.55, blue: 0.58)

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                playerHeader

                // Video player
                playerView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Controls
                playerControls
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            playerController.loadVideo(url: recording.fileURL)
        }
        .onDisappear {
            playerController.cleanup()
        }
    }

    // MARK: - Header

    private var playerHeader: some View {
        HStack {
            Spacer()

            Text(recording.fileName)
                .font(.headline)
                .foregroundColor(.white)

            Spacer()
        }
        .padding()
        .background(backgroundColor)
    }

    // MARK: - Player View

    private var playerView: some View {
        ZStack {
            if let errorMessage = playerController.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text("Playback Error")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(subtleText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if let player = playerController.player {
                VideoPlayer(player: player)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .background(Color.black)
        .onTapGesture {
            playerController.togglePlayPause()
        }
    }

    // MARK: - Controls

    private var playerControls: some View {
        VStack(spacing: 12) {
            // Seek bar
            Slider(
                value: Binding(
                    get: { playerController.currentTime },
                    set: { playerController.seek(to: $0) }
                ),
                in: 0...max(playerController.duration, 0.01)
            )
            .tint(.red)

            HStack {
                // Current time
                Text(formatTime(playerController.currentTime))
                    .font(.caption)
                    .foregroundStyle(subtleText)
                    .monospacedDigit()

                Spacer()

                // Play/Pause
                Button {
                    playerController.togglePlayPause()
                } label: {
                    Image(systemName: playerController.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)

                Spacer()

                // Duration
                Text(formatTime(playerController.duration))
                    .font(.caption)
                    .foregroundStyle(subtleText)
                    .monospacedDigit()
            }
        }
        .padding()
        .background(backgroundColor)
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Video Player Controller

@MainActor
final class VideoPlayerController: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var errorMessage: String?

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var playerForCleanup: AVPlayer?

    func loadVideo(url: URL) {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "Video file not found at: \(url.path)"
            print("❌ Video file not found: \(url.path)")
            return
        }
        
        print("🎬 Loading video from: \(url.path)")
        
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        player = newPlayer
        playerForCleanup = newPlayer

        // Get duration
        Task {
            do {
                let duration = try await playerItem.asset.load(.duration)
                self.duration = duration.seconds
                print("✅ Video duration: \(duration.seconds)s")
            } catch {
                print("⚠️ Could not load duration: \(error.localizedDescription)")
                self.errorMessage = "Could not load video duration"
            }
        }

        // Observe errors
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    print("❌ Playback error: \(error.localizedDescription)")
                    self?.errorMessage = "Playback failed: \(error.localizedDescription)"
                }
            }
            .store(in: &cancellables)

        // Time observer - use MainActor.assumeIsolated since we're on main queue
        timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }

        // Observe playback
        newPlayer.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isPlaying = (status == .playing)
            }
            .store(in: &cancellables)

        // Auto-play
        newPlayer.play()
        isPlaying = true
    }

    func togglePlayPause() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    func pause() {
        player?.pause()
    }

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }

    func cleanup() {
        print("🧹 Cleaning up video player")
        
        // Remove time observer
        if let observer = timeObserver, let player = playerForCleanup {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        // Stop playback
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        
        // Cancel all subscriptions
        cancellables.removeAll()
        
        // Clear references
        player = nil
        playerForCleanup = nil
        
        print("✅ Video player cleanup complete")
    }
    
    deinit {
        print("♻️ VideoPlayerController deinitialized")
        // Safety cleanup in case it wasn't called
        if let observer = timeObserver, let player = playerForCleanup {
            player.removeTimeObserver(observer)
        }
    }
}
