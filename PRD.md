# Loominance

## 🎯 Product Vision
A native macOS screen recording application that delivers cinematic, social-ready video clips instantly after recording—eliminating post-processing time through real-time Core ML-powered cursor prediction and focus zone tracking.

## ❓ Problem Statement
Current screen recording tools like Screen Studio and CleanShot X require time-consuming post-processing to add cinematic zooms and cursor tracking. Content creators and product marketers face friction between recording and sharing, waiting minutes for renders before publishing to social media.

## 🎯 Goals
- Deliver social-ready clips immediately after stopping recording with zero render time
- Predict cursor movement and identify focus zones in real-time using Core ML
- Provide a native macOS experience with SwiftUI and ultra-thin glassmorphism UI
- Maintain full local-first architecture with no server or network dependencies
- Achieve smooth 60fps recording with real-time cinematic zoom effects

## 🚫 Non-Goals
- Cross-platform support (iOS, Windows, or web)
- Cloud storage, synchronization, or sharing features
- Post-processing editing workflows
- Multi-user collaboration
- Browser-based recording

## 👥 Target Users
- Indie developers creating app demo videos for Twitter/X and LinkedIn
- Product marketers producing promotional content
- Content creators specializing in tech tutorials
- Designers showcasing UI animations and interactions
- Customer success teams creating product walkthroughs

## 🧩 Core Features
- Real-time Core ML cursor movement prediction and focus zone identification
- Live cinematic zoom rendering during recording session
- Instant export to MP4 after stopping recording
- SwiftUI recording interface with .ultraThinMaterial glassmorphism
- Customizable recording area selection (full screen, window, or region)
- Keyboard shortcuts for start/stop recording
- Cursor visualization with smooth tracking animations
- Export presets for social platforms (Twitter, LinkedIn, TikTok, Instagram Reels)
- NSPasteboard integration for quick sharing

## ⚙️ Non-Functional Requirements
- 60fps recording performance on Apple Silicon Macs (M1+)
- Under 100ms latency for focus zone prediction and camera movement
- Application launch time under 2 seconds
- Recording files stored locally with efficient compression
- Privacy-first: no telemetry, no network calls, no data leaving the device
- Memory efficient: under 500MB RAM usage during recording
- Native macOS look and feel adhering to Apple Human Interface Guidelines

## 📊 Success Metrics
- Time from stop recording to share-ready export under 5 seconds
- Core ML prediction accuracy: focus zone matches final cursor position 90%+ of time
- User satisfaction: 4.5+ star rating on Mac App Store
- Recording sessions per active user: 5+ per week
- App crash rate under 0.1% during recording sessions

## 📌 Assumptions
- Users have Apple Silicon Macs (M1 or later) for optimal Core ML performance
- Users prioritize speed and convenience over advanced editing capabilities
- Horizontal video format (16:9) is sufficient for target social platforms
- System microphone and system audio capture meet most recording needs
- Local storage is acceptable; cloud sync is not a requirement

## ❓ Open Questions
- Should recorded clips be automatically saved to a configurable library, or only saved on explicit user action?
- What is the maximum recording length before performance degrades with real-time effects?
- Should the app support multiple monitors, and if so, how to handle focus zones spanning displays?
- Is webcam overlay (picture-in-picture style) required for v1?
- What export quality presets are needed (bitrate, resolution, codec)?