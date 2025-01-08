/*
 Window/WindowManager.swift
 Overview

 Created by William Pierce on 1/5/25.

 Manages the creation, configuration, and lifecycle of preview windows,
 coordinating window state persistence and restoration.
*/

import SwiftUI

final class WindowManager {
    // MARK: - Dependencies
    private let appSettings: AppSettings
    private let previewManager: PreviewManager
    private let sourceManager: SourceManager
    private let windowStorage: WindowStorage = WindowStorage.shared
    private let logger = AppLogger.interface

    // MARK: - Private State
    private var activeWindows: Set<NSWindow> = []
    private var windowDelegates: [NSWindow: WindowDelegate] = [:]
    private var sessionWindowCounter: Int

    // MARK: - Constants
    private let cascadeOffset: CGFloat = 25

    init(appSettings: AppSettings, previewManager: PreviewManager, sourceManager: SourceManager) {
        self.appSettings = appSettings
        self.previewManager = previewManager
        self.sourceManager = sourceManager
        self.sessionWindowCounter = 0
        logger.debug("Window service initialized")
    }

    deinit {
        windowDelegates.removeAll()
        activeWindows.removeAll()
        logger.debug("Window service resources cleaned up")
    }

    // MARK: - Window Management

    func createPreviewWindow(at frame: NSRect? = nil) {
        let initialFrame: NSRect = frame ?? createDefaultFrame()
        let validatedFrame: NSRect = initialFrame.ensureOnScreen()

        if validatedFrame != initialFrame {
            logger.info("Adjusted window position to ensure visibility on screen")
        }

        let window: NSWindow = createConfiguredWindow(with: validatedFrame)
        setupWindowDelegate(for: window)
        setupWindowContent(window)

        activeWindows.insert(window)
        sessionWindowCounter += 1

        window.orderFront(nil)
        logger.info("Created new preview window")
    }

    // MARK: - State Management

    func saveWindowStates() {
        windowStorage.saveWindowStates()
    }

    func restoreWindowStates() {
        var restoredCount: Int = 0
        windowStorage.restoreWindows { [weak self] frame in
            self?.createPreviewWindow(at: frame)
            restoredCount += 1
        }

        if restoredCount == 0 {
            logger.info("No windows restored, creating default window")
            createPreviewWindow()
        }
    }

    func validateRestoredWindowCount() -> Bool {
        let currentWindows: Int = activeWindows.count
        let expectedWindows = windowStorage.getStoredWindowCount()

        // Log if there's a mismatch between stored and restored windows
        if currentWindows != expectedWindows {
            logger.warning(
                "Window restoration mismatch: expected=\(expectedWindows), restored=\(currentWindows)"
            )
            return false
        }
        return true
    }

    private func handleWindowRestoreFailure() {
        logger.error("Window restoration failed, creating default window")
        let frame: NSRect = createDefaultFrame()
        createPreviewWindow(at: frame)
    }

    // MARK: - Private Methods

    private func createDefaultFrame() -> NSRect {
        guard let screen: NSScreen = NSScreen.main else {
            logger.warning("No main screen detected, using fallback dimensions")
            return NSRect(
                x: 100, y: 100, width: appSettings.windowDefaultWidth,
                height: appSettings.windowDefaultHeight)
        }

        let defaultWidth = appSettings.windowDefaultWidth
        let defaultHeight = appSettings.windowDefaultHeight

        let visibleFrame: NSRect = screen.visibleFrame

        let centerX = visibleFrame.minX + (visibleFrame.width - defaultWidth) / 2
        let centerY = visibleFrame.minY + (visibleFrame.height - defaultHeight) / 2

        let offset: CGFloat = CGFloat(sessionWindowCounter) * cascadeOffset

        let frame = NSRect(
            x: centerX + offset,
            y: centerY - offset,
            width: defaultWidth,
            height: defaultHeight
        )

        return frame.ensureOnScreen()
    }

    private func createConfiguredWindow(with frame: NSRect) -> NSWindow {
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.level = .statusBar + 1

        return window
    }

    private func setupWindowDelegate(for window: NSWindow) {
        let delegate = WindowDelegate(windowManager: self)
        windowDelegates[window] = delegate
        window.delegate = delegate
    }

    private func setupWindowContent(_ window: NSWindow) {
        let contentView = ContentView(
            appSettings: appSettings,
            previewManager: previewManager,
            sourceManager: sourceManager
        )
        window.contentView = NSHostingView(rootView: contentView)
    }
}

// MARK: - Window Delegate

private final class WindowDelegate: NSObject, NSWindowDelegate {
    private weak var windowManager: WindowManager?

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }
}
