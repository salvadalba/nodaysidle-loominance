# Agent Prompts — Loominance

## 🧭 Global Rules

### ✅ Do
- Use SwiftUI with .ultraThinMaterial for all UI
- Use Combine for reactive streams and publishers
- Use Core ML for all ML/prediction work
- Use SwiftData for local persistence
- Use AVFoundation for screen capture and encoding

### ❌ Don’t
- Do not use any network or server-side code
- Do not use cross-platform frameworks
- Do not introduce alternative ML frameworks
- Do not create a backend API
- Do not use UIKit or AppKit-only views (use SwiftUI)

## 🧩 Task Prompts
## Foundation: Xcode project, error types, logging, and protocols

**Context**
Create the Xcode macOS app project targeting macOS 14+, Apple Silicon only. Establish all protocol definitions, error types, and logging infrastructure that other modules depend on.

### Universal Agent Prompt
```
ROLE: Expert Swift/macOS Engineer

GOAL: Scaffold Xcode project with folder structure, define all error enums, set up OSLog logging subsystem, and create protocol definitions for all services (CaptureSessionProtocol, PredictionServiceProtocol, CinematicEngineProtocol, ExportServiceProtocol, LibraryManagerProtocol, PasteboardServiceProtocol).

CONTEXT: Create the Xcode macOS app project targeting macOS 14+, Apple Silicon only. Establish all protocol definitions, error types, and logging infrastructure that other modules depend on.

FILES TO CREATE:
- Loominance/Models/Errors/CaptureError.swift
- Loominance/Models/Errors/PredictionError.swift
- Loominance/Models/Errors/ExportError.swift
- Loominance/Models/Errors/LibraryError.swift
- Loominance/Models/Errors/PasteboardError.swift
- Loominance/Utils/Logging/Logger.swift
- Loominance/Services/Protocols/CaptureSessionProtocol.swift
- Loominance/Services/Protocols/PredictionServiceProtocol.swift
- Loominance/Services/Protocols/CinematicEngineProtocol.swift
- Loominance/Services/Protocols/ExportServiceProtocol.swift
- Loominance/Services/Protocols/LibraryManagerProtocol.swift
- Loominance/Services/Protocols/PasteboardServiceProtocol.swift

FILES TO MODIFY:
_None_

DETAILED STEPS:
1. Create new Xcode macOS App project named 'Loominance' with SwiftUI, bundle ID 'com.loominance.app', target macOS 14+, Apple Silicon only
2. Create folder structure: Models (Errors, DataModels), Services (Protocols, Implementations), Views, ViewModels, Utils (Logging)
3. Create error enums (CaptureError, PredictionError, ExportError, LibraryError, PasteboardError) conforming to LocalizedError and Error with user-facing descriptions
4. Create OSLog subsystem 'com.loominance' with categories for each service; create Logger utility with convenience methods
5. Create all service protocol files with Combine Publisher return types and associated Error types

VALIDATION:
xcodebuild -scheme Loominance -destination 'platform=macOS' clean build
```