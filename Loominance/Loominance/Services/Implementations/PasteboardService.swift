//
//  PasteboardService.swift
//  Loominance
//
//  Pasteboard service for clipboard operations
//

import AppKit
import Combine
import Foundation

/// Default implementation of PasteboardService
final class PasteboardService: PasteboardServiceProtocol {

    // MARK: - Properties

    private let changeSubject = PassthroughSubject<Int, Never>()
    var changePublisher: AnyPublisher<Int, Never> {
        changeSubject.eraseToAnyPublisher()
    }

    private var changeCount: Int = 0
    private var monitorTimer: Timer?

    // MARK: - Initialization

    init() {
        changeCount = NSPasteboard.general.changeCount
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - PasteboardServiceProtocol

    func copyToPasteboard(url: URL) -> AnyPublisher<PasteboardResult, PasteboardError> {
        return copyToPasteboard(urls: [url])
    }

    func copyToPasteboard(urls: [URL]) -> AnyPublisher<PasteboardResult, PasteboardError> {
        return Future<PasteboardResult, PasteboardError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.pasteboardUnavailable))
                return
            }

            // Verify all files exist
            for url in urls {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    promise(.failure(.fileNotFound(url: url)))
                    return
                }
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            // Write file URLs to pasteboard
            let success = pasteboard.writeObjects(urls as [NSPasteboardWriting])

            if success {
                let result = PasteboardResult(
                    success: true,
                    fileURL: urls.first,
                    changeCount: pasteboard.changeCount
                )

                self.changeCount = pasteboard.changeCount
                AppLogger.pasteboard.info("Copied \(urls.count) file(s) to pasteboard")

                promise(.success(result))
            } else {
                AppLogger.pasteboard.error("Failed to write to pasteboard")
                promise(.failure(.copyFailed(reason: "Failed to write to pasteboard")))
            }
        }
        .eraseToAnyPublisher()
    }

    func hasFileURLs() -> Bool {
        let pasteboard = NSPasteboard.general
        return pasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [
                .urlReadingFileURLsOnly: true
            ])
    }

    func getFileURLs() -> [URL] {
        let pasteboard = NSPasteboard.general

        guard
            let urls = pasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [
                    .urlReadingFileURLsOnly: true
                ]) as? [URL]
        else {
            return []
        }

        return urls
    }

    func clear() {
        NSPasteboard.general.clearContents()
        AppLogger.pasteboard.debug("Pasteboard cleared")
    }

    func startDragSession(with url: URL) {
        // Create NSDraggingItem for drag operation
        let draggingItem = NSDraggingItem(pasteboardWriter: url as NSURL)

        // Set the dragging frame (will be adjusted by the view)
        draggingItem.setDraggingFrame(
            CGRect(x: 0, y: 0, width: 64, height: 64),
            contents: NSImage(systemSymbolName: "doc.fill", accessibilityDescription: nil)
        )

        AppLogger.pasteboard.debug("Drag session started for: \(url.lastPathComponent)")
    }

    func endDragSession() {
        AppLogger.pasteboard.debug("Drag session ended")
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
            [weak self] _ in
            self?.checkForChanges()
        }
    }

    private func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    private func checkForChanges() {
        let currentCount = NSPasteboard.general.changeCount

        if currentCount != changeCount {
            changeCount = currentCount
            changeSubject.send(currentCount)
        }
    }
}

// MARK: - Quick Share Extension

extension PasteboardService {

    /// Copy a recording to the pasteboard and show notification
    func quickShare(recordingURL: URL) -> AnyPublisher<Void, PasteboardError> {
        return copyToPasteboard(url: recordingURL)
            .map { [weak self] result -> Void in
                self?.showQuickShareNotification(for: recordingURL)
                return ()
            }
            .eraseToAnyPublisher()
    }

    private func showQuickShareNotification(for url: URL) {
        let notification = NSUserNotification()
        notification.title = "Recording Copied"
        notification.informativeText = "Ready to paste: \(url.lastPathComponent)"
        notification.soundName = NSUserNotificationDefaultSoundName

        NSUserNotificationCenter.default.deliver(notification)
    }
}
