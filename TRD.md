# Technical Requirements Document

## 🧭 System Context
Loominance is a native macOS screen recording application that delivers cinematic, social-ready video clips instantly after recording. Uses Core ML to predict cursor movement and identify focus zones in real-time, applying cinematic zoom effects during recording rather than post-processing. Entirely local-first with no server dependencies, leveraging Apple Silicon for hardware-accelerated ML inference and video encoding.

## 🔌 API Contracts
### CaptureService
- **Method:** startCapture
- **Path:** Internal
- **Auth:** N/A
- **Request:** { displayId: UUID, frameRate: Int32, captureRect: CGRect }
- **Response:** Publisher<CaptureSession, CaptureError>
- **Errors:**
- PermissionDenied
- DisplayNotFound
- CaptureAlreadyActive

### CaptureService
- **Method:** stopCapture
- **Path:** Internal
- **Auth:** N/A
- **Request:** {}
- **Response:** Publisher<Void, CaptureError>
- **Errors:**
- NoActiveCapture
- WriteFailed

### PredictionService
- **Method:** predictFocusZone
- **Path:** Internal
- **Auth:** N/A
- **Request:** { currentFrame: CVPixelBuffer, cursorPosition: CGPoint, history: [CursorState] }
- **Response:** Publisher<FocusZonePrediction, PredictionError>
- **Errors:**
- ModelLoadFailed
- InvalidInput
- InferenceTimeout

### CinematicEngine
- **Method:** applyZoomEffect
- **Path:** Internal
- **Auth:** N/A
- **Request:** { frame: CVPixelBuffer, focusZone: CGRect, intensity: Float }
- **Response:** CVPixelBuffer
- **Errors:**
- TransformFailed
- BufferPoolExhausted

### ExportService
- **Method:** exportToMP4
- **Path:** Internal
- **Auth:** N/A
- **Request:** { recordingId: UUID, preset: ExportPreset }
- **Response:** Publisher<ExportProgress, ExportError>
- **Errors:**
- FileNotFound
- EncodingFailed
- DiskFull

### LibraryManager
- **Method:** saveRecording
- **Path:** Internal
- **Auth:** N/A
- **Request:** { url: URL, duration: TimeInterval, metadata: RecordingMetadata }
- **Response:** Publisher<Recording, LibraryError>
- **Errors:**
- StorageFull
- WritePermissionDenied

### PasteboardService
- **Method:** copyToPasteboard
- **Path:** Internal
- **Auth:** N/A
- **Request:** { url: URL }
- **Response:** Publisher<Void, PasteboardError>
- **Errors:**
- PasteboardUnavailable
- FileTypeNotSupported

## 🧱 Modules
### CaptureService
- **Responsibilities:**
- Manage screen capture via AVFoundation and CGDisplayStream
- Handle display permissions and screen recording authorization
- Stream captured frames to processing pipeline
- Monitor frame timing for 60fps target
- **Interfaces:**
- CaptureSessionProtocol
- FrameStreamDelegate
- **Depends on:**
- AVFoundation
- CoreGraphics

### PredictionService
- **Responsibilities:**
- Load and manage Core ML models for cursor prediction
- Run real-time inference on captured frames
- Maintain cursor history for trajectory prediction
- Identify focus zones based on cursor movement patterns
- **Interfaces:**
- PredictionServiceProtocol
- ModelProvider
- **Depends on:**
- Core ML
- Accelerate

### CinematicEngine
- **Responsibilities:**
- Apply real-time zoom and pan effects based on predictions
- Manage smooth transitions between focus zones
- Handle frame buffer management
- Coordinate with VideoToolbox for encoding
- **Interfaces:**
- CinematicEngineProtocol
- TransformPipeline
- **Depends on:**
- CoreVideo
- VideoToolbox
- CoreImage

### ExportService
- **Responsibilities:**
- Encode processed frames to MP4 format
- Apply platform-specific presets (Instagram, TikTok, Twitter)
- Handle final file writing and metadata
- Provide export progress updates
- **Interfaces:**
- ExportServiceProtocol
- PresetConfiguration
- **Depends on:**
- AVFoundation
- VideoToolbox

### RecordingManager
- **Responsibilities:**
- Coordinate all services during recording
- Manage recording lifecycle (start, pause, stop)
- Synchronize frame processing with ML predictions
- Handle recording state and error recovery
- **Interfaces:**
- RecordingManagerProtocol
- RecordingCoordinator
- **Depends on:**
- CaptureService
- PredictionService
- CinematicEngine
- ExportService

### LibraryManager
- **Responsibilities:**
- Manage local storage of recorded clips
- Maintain SwiftData metadata store
- Handle recording CRUD operations
- Manage storage quotas and cleanup
- **Interfaces:**
- LibraryManagerProtocol
- StorageProvider
- **Depends on:**
- SwiftData
- Foundation

### PasteboardService
- **Responsibilities:**
- Monitor NSPasteboard for quick share actions
- Handle file copying to clipboard
- Provide drag-and-drop support
- **Interfaces:**
- PasteboardServiceProtocol
- **Depends on:**
- AppKit

### UI
- **Responsibilities:**
- SwiftUI-based main interface
- Recording controls and preview
- Library browsing and management
- Settings and preferences panel
- **Interfaces:**
- Views
- ViewModels
- **Depends on:**
- RecordingManager
- LibraryManager

## 🗃 Data Model Notes
- Recording entity: UUID id, String fileName, TimeInterval duration, Date createdAt, URL fileURL, CGSize resolution, Int32 frameRate, [FocusZoneEvent] focusZones, ExportConfiguration exportConfig
- FocusZoneEvent: TimeInterval timestamp, CGRect zone, Float zoomLevel, TransitionType transitionType
- ExportConfiguration: ExportPreset preset, Bool includeWatermark, Float quality, CGSize outputSize
- CursorState: CGPoint position, TimeInterval timestamp, CGVector velocity
- UserSettings: Bool autoSave, ExportPreset defaultPreset, Float defaultZoomIntensity, Bool showCursorInRecording, StoragePreference storageLocation
- RecordingLibrary: @Model final class with @Relation linking to Recording entities
- Use SwiftData @Model macro for all persistent entities, @Published for observable ViewModels

## 🔐 Validation & Security
- Screen recording permission validation via CGPreflightScreenCaptureAccess
- Screen Recording API requires explicit user consent in System Settings
- File sandboxing for App Store distribution - files written to Application Support directory
- Input validation for all Core ML inputs - buffer size, format, dimensions
- Memory pressure monitoring - throttle capture if system memory exceeds 80%
- Local-first design - no network permissions requested, no data exfiltration
- Code signing and provisioning profile requirements for Mac App Store

## 🧯 Error Handling Strategy
Combine-based error propagation with typed error conformances. CaptureError covers permission and capture failures. PredictionError covers model loading and inference failures. ExportError covers encoding and file I/O failures. Services expose Publisher<T, Error> for reactive error handling. RecordingManager implements circuit-breaker pattern for repeated failures. Critical errors (disk full, permissions) present user-facing alerts with actionable recovery steps.

## 🔭 Observability
- **Logging:** OSLog subsystem with categories: CaptureService, PredictionService, CinematicEngine, ExportService. Log levels: .fault for unrecoverable errors, .error for recoverable failures, .info for state transitions, .debug for frame timing. Logs persist via Console.app for user diagnostics.
- **Tracing:** Instruments integration for performance profiling. Signposts for recording lifecycle events, frame processing pipeline stages, and ML inference. os_signpost intervals for capture-to-export latency measurement.
- **Metrics:**
- Frame processing time (p50, p95, p99)
- Core ML inference latency
- Memory usage during recording
- Frames dropped per second
- Export duration per minute of footage
- Focus zone prediction accuracy

## ⚡ Performance Notes
- Target 60fps capture - 16.67ms budget per frame for capture + prediction + transform
- Core ML model must complete inference under 100ms - use metal compute backend
- Frame buffer pool of 3-5 buffers to prevent stalls, pre-allocated during capture start
- Prediction runs on background DispatchQueue with QoS .userInitiated to prioritize responsiveness
- Zoom transforms use CoreImage hardware acceleration for smooth real-time effects
- Export uses VideoToolbox hardware encoder - H.264/HEVC based on platform capability
- Memory budget under 500MB - monitor with os_memory_pressure_monitor
- Lazy model loading - PredictionService loads model on first use to reduce launch time

## 🧪 Testing Strategy
### Unit
- Focus zone prediction logic with mock cursor history
- Transform pipeline with sample CVPixelBuffer inputs
- Export configuration preset validation
- LibraryManager CRUD operations with in-memory SwiftData container
- ViewModel state transitions with Combine publishers
### Integration
- CaptureService to CinematicEngine frame pipeline
- RecordingManager service coordination with mock dependencies
- PasteboardService file copying to system clipboard
- SwiftData persistence with test schema migrations
### E2E
- Recording session from start to export
- Focus zone prediction accuracy on recorded cursor trajectories
- Export to multiple platform presets with validation
- Memory and performance profiling under extended recording
- Permission flow from fresh install to first recording

## 🚀 Rollout Plan
- Phase 1: Core capture and basic export without ML prediction
- Phase 2: Core ML integration for cursor prediction, static zoom zones
- Phase 3: Real-time cinematic engine with smooth transitions
- Phase 4: Export presets and library management
- Phase 5: Polish and Mac App Store submission

## ❓ Open Questions
_None_