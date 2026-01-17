# Tasks Plan — Loominance

## 📌 Global Assumptions
- Targeting macOS 14+ with Apple Silicon only
- User grants screen recording permission when prompted
- Local storage under 10GB for typical usage
- Core ML model fits within 100MB
- No network connectivity required

## ⚠️ Risks
- Core ML inference may exceed 100ms on older Apple Silicon
- Frame drops if system under heavy load
- Sandboxing may limit file system access
- App Store approval for screen recording apps can be lengthy
- Memory pressure may cause unexpected terminations

## 🧩 Epics
## Foundation & Project Setup
**Goal:** Establish Xcode project structure, SwiftUI app shell, and core architecture patterns

### ✅ Create Xcode project and app structure (1)

Initialize new macOS app project in Xcode with SwiftUI, set up bundle identifier, code signing, and target macOS 14+. Create folder structure: Models, Services, Views, ViewModels, Utils.

**Acceptance Criteria**
- Project builds and runs empty window
- Folder structure follows agreed pattern
- Bundle ID and code signing configured
- Info.plist includes Screen Recording usage description

**Dependencies**
_None_
### ✅ Define error types and Result wrappers (0.5)

Create CaptureError, PredictionError, ExportError, LibraryError, PasteboardError enums conforming to LocalizedError and Error. Create Result aliases for each service.

**Acceptance Criteria**
- All error types defined with user-facing descriptions
- Error types conform to Error
- Unit tests for error descriptions

**Dependencies**
_None_
### ✅ Set up logging infrastructure (0.5)

Create OSLog subsystem for Loominance with categories for each service. Define log levels and configure Console.app output. Create Logger utility with convenience methods.

**Acceptance Criteria**
- OSLog subsystem created with categories
- Logs visible in Console.app
- Logger utility available app-wide

**Dependencies**
- Create Xcode project and app structure
### ✅ Create protocol definitions for all services (1)

Define CaptureSessionProtocol, PredictionServiceProtocol, CinematicEngineProtocol, ExportServiceProtocol, LibraryManagerProtocol, PasteboardServiceProtocol with full method signatures.

**Acceptance Criteria**
- All protocols defined with Combine Publisher return types
- Protocols include associated Error types
- Protocol file created per module

**Dependencies**
- Define error types and Result wrappers

## Screen Capture Foundation
**Goal:** Implement AVFoundation-based screen capture with permission handling and frame streaming

### ✅ Implement screen recording permission handling (1)

Create PermissionManager that checks CGPreflightScreenCaptureAccess, requests CGRequestScreenCaptureAccess, and provides Combine publisher for permission state changes. Show alert if permission denied with directions to System Settings.

**Acceptance Criteria**
- Permission check on app launch
- User prompted when permission missing
- Deep link to System Settings works
- Publisher emits state changes

**Dependencies**
- Create Xcode project and app structure
### ✅ Build CaptureService with CGDisplayStream (2)

Implement CaptureService using CGDisplayStream or AVCaptureScreenInput. Capture at 60fps to CVPixelBuffer. Handle display selection, frame rate configuration, and capture rectangle. Stream frames via Combine publisher.

**Acceptance Criteria**
- Captures selected display at 60fps
- Frames emitted as CVPixelBuffer via Publisher
- Handles capture start/stop cleanly
- No memory leaks after stop

**Dependencies**
- Implement screen recording permission handling
- Create protocol definitions for all services
### ✅ Create frame buffer pool (1.5)

Implement CVPixelBufferPool with 3-5 pre-allocated buffers. Handle buffer acquisition and release. Implement pressure monitoring to throttle if memory exceeds 80%.

**Acceptance Criteria**
- Pool pre-allocates 3-5 buffers
- Buffers properly recycled
- Memory pressure monitoring active
- No buffer exhaustion under normal load

**Dependencies**
- Build CaptureService with CGDisplayStream
### ✅ Add frame timing metrics and signposts (1)

Add os_signpost for capture lifecycle and per-frame timing. Track frames dropped per second. Log p50/p95/p99 latencies.

**Acceptance Criteria**
- Signposts visible in Instruments
- Frame timing logged per frame
- Dropped frame counter works
- Performance metrics collected

**Dependencies**
- Build CaptureService with CGDisplayStream
- Set up logging infrastructure

## Core ML Cursor Prediction
**Goal:** Build ML service that predicts cursor movement and identifies focus zones in real-time

### ✅ Design cursor tracking data model (1)

Create CursorState struct with position, timestamp, velocity. Create FocusZoneEvent with timestamp, zone, zoomLevel, transitionType. Define cursor history buffer structure.

**Acceptance Criteria**
- CursorState struct conforms to Codable
- FocusZoneEvent struct defined
- History buffer with max size limit
- Unit tests for velocity calculation

**Dependencies**
- Define error types and Result wrappers
### ✅ Create Core ML model placeholder (2)

Create simple ML model that takes cursor position history and predicts next focus zone. Start with heuristic model (velocity-based prediction) before training real model. Define input/output schema.

**Acceptance Criteria**
- Model compiles and loads
- Input: current frame buffer + cursor history
- Output: predicted focus zone CGRect
- Heuristic model produces reasonable predictions
- Inference under 100ms

**Dependencies**
- Design cursor tracking data model
### ✅ Implement PredictionService (2)

Build PredictionService that loads Core ML model, runs inference on background DispatchQueue (.userInitiated), maintains cursor history, and emits FocusZonePrediction via Publisher. Handle model load failures and inference timeouts.

**Acceptance Criteria**
- Model loads on first use
- Inference runs on background thread
- Publisher emits predictions
- Timeout after 100ms
- Error handling for load failures

**Dependencies**
- Create Core ML model placeholder
- Create protocol definitions for all services
### ✅ Add cursor tracking integration (1.5)

Track cursor position using CGEvent tap or NSEvent monitoring. Calculate velocity from position deltas. Feed cursor state to PredictionService.

**Acceptance Criteria**
- Cursor position tracked accurately
- Velocity calculated correctly
- Events fed to PredictionService
- Minimal CPU overhead

**Dependencies**
- Implement PredictionService

## Cinematic Engine
**Goal:** Apply real-time zoom and pan effects based on ML predictions using CoreImage/VideoToolbox

### ✅ Implement transform pipeline with CoreImage (2)

Create CinematicEngine that applies zoom and pan transforms to CVPixelBuffer. Use CIContext with hardware acceleration. Implement smooth interpolation between focus zones using easing functions.

**Acceptance Criteria**
- Transforms apply to frames in real-time
- Hardware-accelerated CIContext
- Smooth interpolation between zones
- Output as CVPixelBuffer

**Dependencies**
- Implement PredictionService
- Create frame buffer pool
### ✅ Create transition system for focus zones (1.5)

Implement transition types: instant, ease-in, ease-out, ease-in-out. Manage transition state machine. Handle rapid prediction changes with transition damping.

**Acceptance Criteria**
- All transition types implemented
- Transitions are smooth (no jarring cuts)
- Rapid prediction changes handled gracefully
- Transition state machine works correctly

**Dependencies**
- Implement transform pipeline with CoreImage
### ✅ Integrate with VideoToolbox for encoding (2)

Set up VTCompressionSession for real-time H.264/HEVC encoding. Feed transformed frames to encoder. Configure for low-latency encoding.

**Acceptance Criteria**
- VTCompressionSession configured
- Frames encode in real-time
- Encoded samples available for export
- Platform-appropriate codec selected

**Dependencies**
- Implement transform pipeline with CoreImage
### ✅ Add zoom intensity control (0.5)

Implement configurable zoom intensity (1.0-2.0x). Create UI control for zoom level. Apply intensity to transform calculations.

**Acceptance Criteria**
- Zoom intensity configurable
- UI control works
- Intensity affects transform smoothly
- Default value saved to settings

**Dependencies**
- Create transition system for focus zones

## Recording Coordination
**Goal:** Orchestrate all services during recording with state management and error recovery

### ✅ Create RecordingManager coordinator (2)

Implement RecordingManager that coordinates CaptureService, PredictionService, and CinematicEngine. Manage recording lifecycle: start, pause, stop. Implement state machine (idle, recording, paused, error). Use Combine for reactive coordination.

**Acceptance Criteria**
- Recording state machine works
- All services coordinated properly
- Start/stop transitions clean
- State published for UI observation

**Dependencies**
- Add frame timing metrics and signposts
- Implement PredictionService
- Implement transform pipeline with CoreImage
### ✅ Implement frame synchronization (1.5)

Synchronize captured frames with ML predictions and transforms. Handle prediction latency by buffering frames. Implement timestamp alignment.

**Acceptance Criteria**
- Frames synchronized with predictions
- Prediction latency handled
- Timestamp alignment accurate
- No frame drops during sync

**Dependencies**
- Create RecordingManager coordinator
### ✅ Add error recovery with circuit-breaker (1)

Implement circuit-breaker pattern for repeated failures. Define failure thresholds. Add automatic recovery for transient errors. User alerts for critical errors.

**Acceptance Criteria**
- Circuit-breaker triggers after threshold
- Automatic recovery for transient errors
- User alerts for critical errors
- Circuit-breaker resets on success

**Dependencies**
- Create RecordingManager coordinator
### ✅ Create in-memory recording session model (0.5)

Define RecordingSession model with ID, startTime, duration, frameCount, focusZones array. Manage active session in RecordingManager.

**Acceptance Criteria**
- RecordingSession struct defined
- Session tracked during recording
- Focus zones captured
- Duration calculated accurately

**Dependencies**
- Create RecordingManager coordinator

## SwiftData Library & Persistence
**Goal:** Implement local storage for recordings with SwiftData and file management

### ✅ Define SwiftData schema (1)

Create @Model classes: Recording, FocusZoneEvent, ExportConfiguration, UserSettings. Set up relationships with @Relation. Configure indexes for common queries.

**Acceptance Criteria**
- @Model classes compile
- Relationships defined correctly
- Indexes on queried fields
- Schema migrates cleanly

**Dependencies**
_None_
### ✅ Implement SwiftData container (1)

Set up ModelContainer in app. Configure for App Store sandboxing. Store database in Application Support directory. Handle migration between versions.

**Acceptance Criteria**
- ModelContainer initialized on launch
- Database in correct directory
- Sandboxing compliant
- Migration strategy defined

**Dependencies**
- Define SwiftData schema
### ✅ Build LibraryManager (2)

Implement LibraryManager with CRUD operations for Recording entities. Handle file I/O for video files. Implement storage quota monitoring and cleanup.

**Acceptance Criteria**
- Create, read, update, delete recordings
- Files saved to disk correctly
- Storage quota monitored
- Cleanup of old recordings works

**Dependencies**
- Implement SwiftData container
- Create protocol definitions for all services
### ✅ Add recording export from library (1.5)

Implement export of existing recordings to new presets. Allow re-export with different settings. Export progress reporting.

**Acceptance Criteria**
- Re-export from library works
- Preset can be changed
- Progress reported via Publisher
- Export creates new file

**Dependencies**
- Build LibraryManager

## Export Service & Presets
**Goal:** Encode recordings to MP4 with platform-specific presets for social media

### ✅ Create export preset configurations (1)

Define ExportPreset enum: instagramSquare, instagramPortrait, tikTok, twitter, custom. Each preset includes resolution, aspect ratio, bitrate target, codec settings.

**Acceptance Criteria**
- All platform presets defined
- Custom preset configurable
- Presets conform to platform specs
- Preset selection UI works

**Dependencies**
_None_
### ✅ Implement ExportService with AVAssetWriter (2.5)

Build ExportService using AVAssetWriter for MP4 output. Support H.264/HEVC codecs. Implement progress reporting via Publisher. Handle encoding failures and disk full scenarios.

**Acceptance Criteria**
- MP4 files created successfully
- Progress reporting works
- Encoding errors handled gracefully
- Disk full detected and reported

**Dependencies**
- Create export preset configurations
- Create protocol definitions for all services
### ✅ Add watermark overlay option (1)

Implement optional watermark overlay using CALayer or CIFilter. Configurable watermark image and position. Toggle in export settings.

**Acceptance Criteria**
- Watermark renders correctly
- Position configurable
- Toggle works
- Watermark survives encoding

**Dependencies**
- Implement ExportService with AVAssetWriter
### ✅ Create export progress UI (0.5)

Build SwiftUI view showing export progress with percentage, time remaining, and cancel button. Use @Published progress from ExportService.

**Acceptance Criteria**
- Progress shows percentage
- Time remaining estimated
- Cancel button works
- UI updates smoothly

**Dependencies**
- Implement ExportService with AVAssetWriter

## Pasteboard & Quick Share
**Goal:** Enable instant sharing via clipboard and drag-and-drop

### ✅ Implement PasteboardService (1)

Create PasteboardService that copies file URLs to NSPasteboard. Monitor pasteboard for changes. Handle pasteboard unavailability. Support both file and URL types.

**Acceptance Criteria**
- Files copy to clipboard
- Pasteboard monitored for changes
- Errors handled gracefully
- Works with drag-and-drop

**Dependencies**
- Create protocol definitions for all services
### ✅ Add quick share keyboard shortcut (0.5)

Implement global keyboard shortcut (Cmd+Shift+S) to copy last recording to clipboard. Register with NSHotKey or similar. Show notification on success.

**Acceptance Criteria**
- Shortcut works globally
- Last recording copied
- Notification shown
- Shortcut configurable in settings

**Dependencies**
- Implement PasteboardService

## SwiftUI Interface
**Goal:** Build native macOS UI with .ultraThinMaterial and modern design

### ✅ Create main window and app shell (1)

Build main app window with SwiftUI. Use .ultraThinMaterial for glass effect. Implement window controls (close, minimize, fullscreen). Set up app lifecycle.

**Acceptance Criteria**
- Window opens with glass effect
- Standard window controls work
- App lifecycle correct
- Window size and position saved

**Dependencies**
- Create Xcode project and app structure
### ✅ Build recording controls view (1.5)

Create recording button with pulsing animation when recording. Add stop button. Show recording timer. Display frame rate and resolution info.

**Acceptance Criteria**
- Record button starts recording
- Pulsing animation when active
- Timer displays correctly
- Stop button ends recording

**Dependencies**
- Create RecordingManager coordinator
### ✅ Create preview player view (2)

Build video player using AVPlayerLayer in SwiftUI. Show playback controls. Display focus zone overlay. Support scrubbing and frame-by-frame.

**Acceptance Criteria**
- Video plays smoothly
- Scrubbing works
- Focus zones visible
- Playback controls functional

**Dependencies**
- Create recording controls view
- Build LibraryManager
### ✅ Build library browser view (2)

Create grid/list view of recordings. Show thumbnails, duration, date. Support selection and bulk actions. Implement search and filter.

**Acceptance Criteria**
- Recordings display in grid/list
- Thumbnails load correctly
- Search works
- Filter by date/duration

**Dependencies**
- Build LibraryManager
### ✅ Create settings panel (1.5)

Build settings view with sections: General, Recording, Export, Storage. Implement controls for defaults: zoom intensity, preset, storage location, auto-save.

**Acceptance Criteria**
- All settings accessible
- Changes persist to SwiftData
- Reset to defaults works
- Validation on inputs

**Dependencies**
- Build LibraryManager
### ✅ Add matchedGeometryEffect transitions (1)

Apply matchedGeometryEffect for smooth view transitions. Implement hero animations from library to player. Add spring animations for interactions.

**Acceptance Criteria**
- Smooth transitions between views
- Hero animation works
- Spring animations feel natural
- No jarring layout changes

**Dependencies**
- Build library browser view
- Create preview player view

## Polish & Release
**Goal:** Final polish, testing, and Mac App Store submission preparation

### ✅ Implement comprehensive error UI (1)

Create user-friendly error alerts for all error types. Add recovery actions. Implement error reporting (optional crash logs). Show inline errors where appropriate.

**Acceptance Criteria**
- All errors have user-facing messages
- Recovery actions provided
- Alerts dismiss properly
- Error styling consistent

**Dependencies**
- Create settings panel
### ✅ Add onboarding experience (1.5)

Create first-launch onboarding flow. Explain app features. Request screen recording permission with clear explanation. Set initial preferences.

**Acceptance Criteria**
- Onboarding shows on first launch
- Permission request clear
- Features explained
- Can be skipped or replayed

**Dependencies**
- Create main window and app shell
### ✅ Performance profiling and optimization (2)

Profile with Instruments. Optimize hot paths. Ensure 60fps sustained. Reduce memory usage under 500MB. Fix any leaks.

**Acceptance Criteria**
- 60fps sustained during recording
- Memory under 500MB
- No leaks detected
- Optimization targets met

**Dependencies**
- Add frame timing metrics and signposts
### ✅ App Store submission preparation (2)

Create app store listing assets (screenshots, description). Configure app privacy details. Set up provisioning profiles. Test TestFlight build.

**Acceptance Criteria**
- Screenshots captured
- Description written
- Privacy details configured
- TestFlight build installs

**Dependencies**
- Performance profiling and optimization

## ❓ Open Questions
- Should we train custom Core ML model or use heuristics initially?
- What is the maximum recording duration we should support?
- Do we need to support multiple displays simultaneously?
- Should we include a watermark in free version?