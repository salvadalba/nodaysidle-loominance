//
//  CinematicEngine.swift
//  Loominance
//
//  Real-time cinematic zoom and pan effects engine
//

import Combine
import CoreGraphics
import CoreImage
import CoreVideo
import Foundation
import QuartzCore

/// Default implementation of the cinematic effects engine
final class CinematicEngine: CinematicEngineProtocol {

    // MARK: - Properties

    var configuration: ZoomConfiguration = .default

    private(set) var currentZoomLevel: Float = 1.0
    private(set) var currentFocusZone: CGRect = .zero

    private let stateSubject = CurrentValueSubject<CinematicState, Never>(.idle)
    var statePublisher: AnyPublisher<CinematicState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    // Transition state
    private var targetFocusZone: CGRect = .zero
    private var targetZoomLevel: Float = 1.0
    private var transitionStartTime: TimeInterval?
    private var transitionDuration: TimeInterval = 0.3
    private var currentTransitionType: TransitionType = .easeInOut

    // Buffer pool
    private var pixelBufferPool: CVPixelBufferPool?
    private var ciContext: CIContext?

    // Frame dimensions
    private var frameWidth: Int = 1920
    private var frameHeight: Int = 1080

    // MARK: - Initialization

    init() {
        // Create CIContext with Metal acceleration
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            ciContext = CIContext(mtlDevice: metalDevice)
            AppLogger.cinematic.info("CinematicEngine initialized with Metal acceleration")
        } else {
            ciContext = CIContext()
            AppLogger.cinematic.warning("CinematicEngine using CPU rendering (no Metal)")
        }
    }

    // MARK: - CinematicEngineProtocol

    func applyZoomEffect(
        frame: CVPixelBuffer,
        focusZone: CGRect,
        intensity: Float?
    ) -> Result<TransformResult, TransformError> {

        guard let context = ciContext else {
            return .failure(.contextCreationFailed)
        }

        stateSubject.send(.processing)

        // Update target focus zone
        if focusZone != targetFocusZone {
            setTargetFocusZone(focusZone, transitionType: currentTransitionType)
        }

        // Calculate current interpolated state
        let (interpolatedZone, interpolatedZoom, isTransitioning, progress) =
            calculateInterpolatedState(intensity: intensity ?? configuration.defaultIntensity)

        // Create CIImage from pixel buffer
        let inputImage = CIImage(cvPixelBuffer: frame)

        // Apply zoom transform
        guard
            let transformedImage = applyTransform(
                to: inputImage,
                focusZone: interpolatedZone,
                zoomLevel: interpolatedZoom
            )
        else {
            return .failure(.transformFailed(reason: "Failed to apply transform"))
        }

        // Render to output buffer
        guard let outputBuffer = renderToBuffer(image: transformedImage, context: context) else {
            return .failure(.bufferPoolExhausted)
        }

        // Update current state
        currentFocusZone = interpolatedZone
        currentZoomLevel = interpolatedZoom

        if isTransitioning {
            stateSubject.send(.transitioning(progress: progress))
        } else {
            stateSubject.send(.idle)
        }

        return .success(
            TransformResult(
                pixelBuffer: outputBuffer,
                currentZoomLevel: interpolatedZoom,
                currentFocusZone: interpolatedZone,
                isTransitioning: isTransitioning,
                transitionProgress: progress
            ))
    }

    func setTargetFocusZone(_ zone: CGRect, transitionType: TransitionType) {
        // Apply damping to prevent rapid changes
        let dampedZone = applyDamping(newZone: zone, currentZone: currentFocusZone)

        targetFocusZone = dampedZone
        currentTransitionType = transitionType
        transitionStartTime = CACurrentMediaTime()
        transitionDuration = configuration.transitionDuration

        AppLogger.cinematic.debug(
            "New target focus zone: \(zone.debugDescription), transition: \(transitionType.rawValue)"
        )
    }

    func setZoomIntensity(_ intensity: Float) {
        let clampedIntensity = min(max(intensity, configuration.minZoom), configuration.maxZoom)
        targetZoomLevel = clampedIntensity
        AppLogger.cinematic.debug("Zoom intensity set to: \(clampedIntensity)")
    }

    func reset() {
        currentZoomLevel = 1.0
        currentFocusZone = CGRect(
            x: CGFloat(frameWidth) / 2 - 200,
            y: CGFloat(frameHeight) / 2 - 200,
            width: 400,
            height: 400
        )
        targetFocusZone = currentFocusZone
        targetZoomLevel = 1.0
        transitionStartTime = nil
        stateSubject.send(.idle)

        AppLogger.cinematic.info("CinematicEngine reset")
    }

    func prepareBufferPool(width: Int, height: Int, bufferCount: Int) {
        frameWidth = width
        frameHeight = height

        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: bufferCount
        ]

        let bufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]

        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            bufferAttributes as CFDictionary,
            &pool
        )

        if status == kCVReturnSuccess {
            pixelBufferPool = pool
            AppLogger.cinematic.info(
                "Buffer pool created: \(width)x\(height), \(bufferCount) buffers")
        } else {
            AppLogger.cinematic.error("Failed to create buffer pool: \(status)")
        }

        // Initialize focus zone to center
        reset()
    }

    func releaseBufferPool() {
        pixelBufferPool = nil
        AppLogger.cinematic.info("Buffer pool released")
    }

    // MARK: - Private Methods

    private func calculateInterpolatedState(intensity: Float) -> (
        CGRect, Float, Bool, Float
    ) {
        guard let startTime = transitionStartTime else {
            return (currentFocusZone, currentZoomLevel, false, 1.0)
        }

        let elapsed = CACurrentMediaTime() - startTime
        let progress = min(Float(elapsed / transitionDuration), 1.0)

        if progress >= 1.0 {
            // Transition complete
            transitionStartTime = nil
            return (targetFocusZone, intensity, false, 1.0)
        }

        // Apply easing
        let easedProgress = applyEasing(progress: progress, type: currentTransitionType)

        // Interpolate zone
        let interpolatedZone = CGRect(
            x: lerp(currentFocusZone.origin.x, targetFocusZone.origin.x, CGFloat(easedProgress)),
            y: lerp(currentFocusZone.origin.y, targetFocusZone.origin.y, CGFloat(easedProgress)),
            width: lerp(currentFocusZone.width, targetFocusZone.width, CGFloat(easedProgress)),
            height: lerp(currentFocusZone.height, targetFocusZone.height, CGFloat(easedProgress))
        )

        // Interpolate zoom
        let interpolatedZoom = lerp(currentZoomLevel, intensity, easedProgress)

        return (interpolatedZone, interpolatedZoom, true, progress)
    }

    private func applyEasing(progress: Float, type: TransitionType) -> Float {
        switch type {
        case .instant:
            return 1.0
        case .easeIn:
            return progress * progress
        case .easeOut:
            return 1.0 - (1.0 - progress) * (1.0 - progress)
        case .easeInOut:
            if progress < 0.5 {
                return 2.0 * progress * progress
            } else {
                return 1.0 - pow(-2.0 * progress + 2.0, 2) / 2.0
            }
        }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        return a + (b - a) * t
    }

    private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a + (b - a) * t
    }

    private func applyDamping(newZone: CGRect, currentZone: CGRect) -> CGRect {
        let factor = CGFloat(configuration.dampingFactor)
        return CGRect(
            x: currentZone.origin.x + (newZone.origin.x - currentZone.origin.x) * (1 - factor),
            y: currentZone.origin.y + (newZone.origin.y - currentZone.origin.y) * (1 - factor),
            width: currentZone.width + (newZone.width - currentZone.width) * (1 - factor),
            height: currentZone.height + (newZone.height - currentZone.height) * (1 - factor)
        )
    }

    private func applyTransform(
        to image: CIImage,
        focusZone: CGRect,
        zoomLevel: Float
    ) -> CIImage? {

        let imageExtent = image.extent

        // Calculate center of focus zone
        let centerX = focusZone.midX
        let centerY = focusZone.midY

        // Calculate scale
        let scale = CGFloat(zoomLevel)

        // Create transform: translate to center, scale, translate back
        let translateToOrigin = CGAffineTransform(
            translationX: -centerX,
            y: -centerY
        )

        let scaleTransform = CGAffineTransform(
            scaleX: scale,
            y: scale
        )

        let translateBack = CGAffineTransform(
            translationX: imageExtent.width / 2,
            y: imageExtent.height / 2
        )

        let combinedTransform =
            translateToOrigin
            .concatenating(scaleTransform)
            .concatenating(translateBack)

        // Apply transform
        let transformedImage = image.transformed(by: combinedTransform)

        // Crop to original size
        let cropRect = CGRect(
            x: 0,
            y: 0,
            width: imageExtent.width,
            height: imageExtent.height
        )

        return transformedImage.cropped(to: cropRect)
    }

    private func renderToBuffer(image: CIImage, context: CIContext) -> CVPixelBuffer? {
        guard let pool = pixelBufferPool else {
            // Create a one-off buffer if no pool
            var buffer: CVPixelBuffer?
            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                frameWidth,
                frameHeight,
                kCVPixelFormatType_32BGRA,
                [kCVPixelBufferMetalCompatibilityKey as String: true] as CFDictionary,
                &buffer
            )

            guard status == kCVReturnSuccess, let outputBuffer = buffer else {
                return nil
            }

            context.render(image, to: outputBuffer)
            return outputBuffer
        }

        var outputBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &outputBuffer)

        guard status == kCVReturnSuccess, let buffer = outputBuffer else {
            AppLogger.cinematic.warning("Failed to get buffer from pool")
            return nil
        }

        context.render(image, to: buffer)
        return buffer
    }
}
