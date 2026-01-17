# Architecture Requirements Document

## 🧱 System Overview
Loominance is a native macOS screen recording application that delivers cinematic, social-ready video clips instantly after recording. The system uses Core ML to predict cursor movement and identify focus zones in real-time, applying cinematic zoom effects during recording rather than in post-processing. The architecture is entirely local-first with no server or network dependencies, leveraging Apple Silicon for hardware-accelerated ML inference and video encoding.

## 🏗 Architecture Style
Native macOS application using Model-View-ViewModel (MVVM) pattern with SwiftUI for the interface, Combine for reactive data flow, and Core ML for on-device machine learning inference. The recording pipeline operates on a real-time frame processing loop with parallel ML prediction and video encoding.

## 🎨 Frontend Architecture
- **Framework:** SwiftUI with .ultraThinMaterial glassmorphism design system
- **State Management:** Combine framework for reactive state propagation, @StateObject and @ObservedObject for view state, @Published for observable properties
- **Routing:** Single-window macOS application with NavigationView for internal navigation, sheet-based modal presentation for overlays and settings
- **Build Tooling:** Xcode project with native Swift Package Manager for dependencies, swiftformat for code formatting, swiftlint for linting

## 🧠 Backend Architecture
- **Approach:** Native Swift services with AVFoundation for capture, Core ML for inference, and VideoToolbox for hardware-accelerated encoding. Services communicate via Combine publishers and operate on a shared recording session context.
- **API Style:** No REST API. Internal service communication via Combine publishers, protocol-oriented interfaces, and dependency injection. External integrations via NSPasteboard and file system APIs.
- **Services:**
- CaptureService - Manages screen capture via AVFoundation and CGDisplayStream
- PredictionService - Core ML model inference for cursor prediction and focus zone detection
- CinematicEngine - Applies real-time zoom and pan effects based on predictions
- ExportService - Handles MP4 encoding with preset configurations for social platforms
- RecordingManager - Coordinates all services and manages recording lifecycle
- LibraryManager - Manages local storage and metadata for recorded clips
- PasteboardService - Handles NSPasteboard integration for quick sharing

## 🗄 Data Layer
- **Primary Store:** SwiftData for local metadata storage (recordings, presets, settings), raw MP4 files stored in Application Support directory
- **Relationships:** Recording entity has many ExportConfiguration entities, UserSettings singleton stores preferences, RecordingLibrary manages collection
- **Migrations:** SwiftData automatic schema migrations with versioned models, manual migration scripts for breaking changes

## ☁️ Infrastructure
- **Hosting:** Mac App Store distribution, local-only application with no cloud infrastructure
- **Scaling Strategy:** Single-device application, optimization targets Apple Silicon M1+, hardware acceleration via GPU for ML inference and video encoding
- **CI/CD:** GitHub Actions for build validation, TestFlight for beta distribution, automated Mac App Store submission via fastlane

## ⚖️ Key Trade-offs
- Real-time ML prediction eliminates post-processing but limits maximum recording length and requires Apple Silicon
- Local-first architecture ensures privacy and zero latency but precludes cloud sync and cross-device access
- SwiftUI enables rapid UI development and native feel but requires macOS 14+ and may have performance limitations for complex animations
- Core ML provides fast on-device inference but requires custom model training and limits model complexity compared to server-side ML
- Hardware-accelerated encoding ensures performance but locks application to Apple ecosystem

## 📐 Non-Functional Requirements
- 60fps recording performance with under 16.67ms frame processing time
- Core ML prediction latency under 100ms for focus zone detection
- Application launch time under 2 seconds
- Memory usage under 500MB during recording
- Time from stop to export completion under 5 seconds for typical 30-second clips
- Privacy-first: no telemetry, no network calls, no data leaving device
- Native macOS HIG compliance with .ultraThinMaterial design language
- Crash rate under 0.1% during recording sessions
- Focus zone prediction accuracy 90%+ matching final cursor position