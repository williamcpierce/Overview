/*
 Window/WindowService.swift
 Overview

 Created by William Pierce on 1/5/25.

 Manages the creation, configuration, and lifecycle of preview windows,
 coordinating window state persistence and restoration.
*/

import SwiftUI

final class WindowService {
    // MARK: - Dependencies
    private let settings: AppSettings
    private let previewManager: PreviewManager
    private let sourceManager: SourceManager
    private let stateManager: WindowStateManager
    private let logger = AppLogger.interface

    // MARK: - Private State
    private var activeWindows: Set<NSWindow> = []
    private var windowDelegates: [NSWindow: WindowDelegate] = [:]

    init(settings: AppSettings, preview: PreviewManager, source: SourceManager) {
        self.settings = settings
        self.previewManager = preview
        self.sourceManager = source
        self.stateManager = WindowStateManager()
        logger.debug("Window service initialized")
    }

    deinit {
        cleanupResources()
    }

    // MARK: - Window Management

    func createPreviewWindow(at frame: NSRect? = nil) {
        let windowFrame = frame ?? createDefaultFrame()
        let window = createConfiguredWindow(with: windowFrame)
        setupWindowDelegate(for: window)
        setupWindowContent(window)
        
        activeWindows.insert(window)
        window.orderFront(nil)
        logger.info("Created new preview window")
    }

    func closeAllPreviewWindows() {
        let windowsToClose = activeWindows
        windowsToClose.forEach(closeWindow)
        logger.info("Closed \(windowsToClose.count) preview windows")
    }

    func closeWindow(_ window: NSWindow) {
        cleanupWindow(window)
        window.close()
    }

    // MARK: - State Management

    func saveWindowStates() {
        stateManager.saveWindowStates()
    }

    func restoreWindowStates() {
        stateManager.restoreWindows { [weak self] frame in
            self?.createPreviewWindow(at: frame)
        }
    }

    // MARK: - Private Methods

    private func createDefaultFrame() -> NSRect {
        NSRect(
            x: 100, y: 100,
            width: settings.previewDefaultWidth,
            height: settings.previewDefaultHeight
        )
    }

    private func createConfiguredWindow(with frame: NSRect) -> NSWindow {
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.level = .statusBar + 1
        window.collectionBehavior = [.fullScreenAuxiliary]
        
        return window
    }

    private func setupWindowDelegate(for window: NSWindow) {
        let delegate = WindowDelegate(windowService: self)
        windowDelegates[window] = delegate
        window.delegate = delegate
    }

    private func setupWindowContent(_ window: NSWindow) {
        let contentView = ContentView(
            appSettings: settings,
            previewManager: previewManager,
            sourceManager: sourceManager
        )
        window.contentView = NSHostingView(rootView: contentView)
    }

    private func cleanupWindow(_ window: NSWindow) {
        activeWindows.remove(window)
        windowDelegates.removeValue(forKey: window)
    }

    private func cleanupResources() {
        windowDelegates.removeAll()
        activeWindows.removeAll()
        logger.debug("Window service resources cleaned up")
    }
}

// MARK: - Window Delegate

private final class WindowDelegate: NSObject, NSWindowDelegate {
    private weak var windowService: WindowService?

    init(windowService: WindowService) {
        self.windowService = windowService
    }
}
