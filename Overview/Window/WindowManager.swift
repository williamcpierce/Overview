/*
 Window/WindowManager.swift
 Overview

 Created by William Pierce on 1/12/25.

 Coordinates window lifecycle management and state persistence.
*/

import SwiftUI

@MainActor
final class WindowManager: ObservableObject {
    // Dependencies
    private var previewManager: PreviewManager
    private var sourceManager: SourceManager
    private var layoutManager: LayoutManager
    private var permissionManager: PermissionManager
    private let windowServices: WindowServices = WindowServices.shared
    private let logger = AppLogger.interface

    // Private State
    private var activeWindows: Set<NSWindow> = []
    private var windowDelegates: [NSWindow: WindowDelegate] = [:]
    private var windowTitleBindings: [NSWindow: String] = [:]
    private var sessionWindowCounter: Int

    // Window Settings
    @AppStorage(WindowSettingsKeys.shadowEnabled)
    private var shadowEnabled = WindowSettingsKeys.defaults.shadowEnabled
    @AppStorage(WindowSettingsKeys.defaultWidth)
    private var defaultWidth = WindowSettingsKeys.defaults.defaultWidth
    @AppStorage(WindowSettingsKeys.defaultHeight)
    private var defaultHeight = WindowSettingsKeys.defaults.defaultHeight
    @AppStorage(WindowSettingsKeys.createOnLaunch)
    private var createOnLaunch = WindowSettingsKeys.defaults.createOnLaunch
    @AppStorage(WindowSettingsKeys.saveWindowsOnQuit)
    private var saveWindowsOnQuit = WindowSettingsKeys.defaults.saveWindowsOnQuit
    @AppStorage(WindowSettingsKeys.restoreWindowsOnLaunch)
    private var restoreWindowsOnLaunch = WindowSettingsKeys.defaults.restoreWindowsOnLaunch
    @AppStorage(WindowSettingsKeys.bindWindowsToTitles)
    private var bindWindowsToTitles = WindowSettingsKeys.defaults.bindWindowsToTitles

    init(
        previewManager: PreviewManager,
        sourceManager: SourceManager,
        permissionManager: PermissionManager,
        layoutManager: LayoutManager
    ) {
        self.previewManager = previewManager
        self.sourceManager = sourceManager
        self.permissionManager = permissionManager
        self.layoutManager = layoutManager
        self.sessionWindowCounter = 0
        logger.debug("Window manager initialized")
    }

    func createWindow(at frame: NSRect? = nil, boundTitle: String? = nil) throws {
        do {
            let defaultSize = CGSize(width: defaultWidth, height: defaultHeight)
            let window = try windowServices.createWindow(
                defaultSize: defaultSize,
                windowCount: sessionWindowCounter,
                providedFrame: frame)

            // Store title binding if provided
            if let boundTitle = boundTitle, !boundTitle.isEmpty {
                windowTitleBindings[window] = boundTitle
                logger.info("Creating window with bound title: '\(boundTitle)'")
            }

            configureWindow(window)
            
            activeWindows.insert(window)
            sessionWindowCounter += 1

            window.orderFront(self)
            logger.info("Created new preview window: id=\(sessionWindowCounter)")
        } catch {
            logger.logError(error, context: "Failed to create preview window")
            throw WindowManagerError.windowCreationFailed
        }
    }

    func closeWindow(_ window: NSWindow) {
        Task {
            window.orderOut(self)
            activeWindows.remove(window)
            windowDelegates.removeValue(forKey: window)
            windowTitleBindings.removeValue(forKey: window)
            logger.debug("Window closed successfully")
        }
    }

    func handleWindowsOnLaunch() {
        if layoutManager.shouldApplyLayoutOnLaunch(),
            let launchLayout = layoutManager.getLaunchLayout()
        {
            applyLayout(launchLayout)
            return
        }

        var restoredCount: Int = 0

        if restoreWindowsOnLaunch {
            windowServices.windowStorage.restoreWindows { [weak self] frame, boundTitle in
                guard let self = self else { return }
                do {
                    if bindWindowsToTitles {
                        try createWindow(at: frame, boundTitle: boundTitle)
                    } else {
                        try createWindow(at: frame)
                    }
                    restoredCount += 1
                    logger.debug("Restored window \(restoredCount)")
                } catch {
                    logger.logError(error, context: "Failed to restore window \(restoredCount + 1)")
                }
            }
        }

        handleRestoreCompletion(restoredCount)
    }

    func handleWindowsOnQuit() {
        if saveWindowsOnQuit {
            let windowStates = activeWindows.compactMap { window in
                let boundTitle = windowTitleBindings[window] ?? getCapturedWindowTitle(window)
                return WindowState(frame: window.frame, boundWindowTitle: boundTitle)
            }
            windowServices.windowStorage.storeWindows(windowStates)
        }
    }

    func saveLayout(name: String) -> Layout? {
        let layout = layoutManager.createLayout(name: name)
        return layout
    }

    func applyLayout(_ layout: Layout) {
        closeAllWindows()

        windowServices.windowStorage.applyWindows(layout.windows) { [weak self] frame in
            guard let self = self else { return }
            do {
                try createWindow(at: frame)
            } catch {
                logger.logError(
                    error, context: "Failed to create window from layout '\(layout.name)'")
            }
        }
        logger.info("Applied window layout: '\(layout.name)'")
    }
    
    func updateWindowTitleBinding(_ window: NSWindow, title: String?) {
        if let title = title, !title.isEmpty {
            windowTitleBindings[window] = title
            logger.debug("Updated window title binding: '\(title)'")
        } else {
            windowTitleBindings.removeValue(forKey: window)
            logger.debug("Removed window title binding")
        }
    }

    // MARK: - Private Methods

    private func createDefaultWindow() {
        do {
            try createWindow()
        } catch {
            logger.logError(error, context: "Failed to create default window")
        }
    }

    private func configureWindow(_ window: NSWindow) {
        windowServices.windowConfiguration.applyConfiguration(to: window, hasShadow: shadowEnabled)
        setupWindowDelegate(for: window)
        setupWindowContent(window)
    }

    private func setupWindowDelegate(for window: NSWindow) {
        let delegate = WindowDelegate(windowManager: self)
        windowDelegates[window] = delegate
        window.delegate = delegate
        logger.debug("Window delegate configured: id=\(sessionWindowCounter)")
    }

    private func setupWindowContent(_ window: NSWindow) {
        let contentView = PreviewView(
            previewManager: previewManager,
            sourceManager: sourceManager,
            permissionManager: permissionManager,
            initialBoundTitle: windowTitleBindings[window],
            onTitleChange: { [weak self, weak window] title in
                guard let window = window else { return }
                self?.updateWindowTitleBinding(window, title: title)
            },
            onClose: { [weak self, weak window] in
                guard let window = window else { return }
                self?.closeWindow(window)
            }
        )
        window.contentView = NSHostingView(rootView: contentView)
    }
    
    // This function is removed as we handle binding directly in PreviewView initialization
    
    private func getCapturedWindowTitle(_ window: NSWindow) -> String? {
        // This is called when saving window states
        // We're looking for the currently captured source title
        // We'll use the bound title if it exists, otherwise try to get the current title
        
        // The title binding would be updated during capture via the onTitleChange callback
        return windowTitleBindings[window]
    }

    private func closeAllWindows() {
        let windowsToClose = activeWindows
        for window in windowsToClose {
            closeWindow(window)
        }
    }

    private func handleRestoreCompletion(_ restoredCount: Int) {
        if restoredCount == 0 && createOnLaunch {
            logger.info("No windows restored, creating default window")
            createDefaultWindow()
        } else {
            logger.info("Successfully restored \(restoredCount) windows")
        }
    }
}

// MARK: - Window Delegate

private final class WindowDelegate: NSObject, NSWindowDelegate {
    private weak var windowManager: WindowManager?

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        super.init()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        windowManager?.closeWindow(window)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let bindWindowToTitle = Notification.Name("bindWindowToTitle")
}

// MARK: - Supporting Types

enum WindowManagerError: LocalizedError {
    case windowCreationFailed
    case invalidScreenConfiguration

    var errorDescription: String? {
        switch self {
        case .windowCreationFailed:
            return "Failed to create window with valid configuration"
        case .invalidScreenConfiguration:
            return "No valid screen configuration available"
        }
    }
}
