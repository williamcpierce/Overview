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
    private let cascadeOffsetMultiplier: CGFloat = 25

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
        let windowFrame: NSRect = frame ?? createDefaultFrame()
        let window: NSWindow = createConfiguredWindow(with: windowFrame)
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
        windowStorage.restoreWindows { [weak self] frame in
            self?.createPreviewWindow(at: frame)
        }
    }

    // MARK: - Private Methods

    private func createDefaultFrame() -> NSRect {
        guard let screenFrame: NSRect = NSScreen.main?.frame else {
            logger.warning("Unable to retrieve main screen frame, defaulting to zero")
            return .zero
        }

        let centerX = (screenFrame.width - appSettings.windowDefaultWidth) / 2
        let centerY = (screenFrame.height - appSettings.windowDefaultHeight) / 2

        let xOffset: CGFloat = CGFloat(sessionWindowCounter) * cascadeOffsetMultiplier
        let yOffset: CGFloat = CGFloat(sessionWindowCounter) * cascadeOffsetMultiplier

        return NSRect(
            x: centerX + xOffset,
            y: centerY - yOffset,
            width: appSettings.windowDefaultWidth,
            height: appSettings.windowDefaultHeight
        )
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
