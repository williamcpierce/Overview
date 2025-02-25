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

    func createPreviewWindow(at frame: NSRect? = nil) throws {
        do {
            let defaultSize = CGSize(width: defaultWidth, height: defaultHeight)
            let window = try windowServices.createWindow(
                defaultSize: defaultSize,
                windowCount: sessionWindowCounter,
                providedFrame: frame)

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
            logger.debug("Initiating window closure")
            window.orderOut(self)
            activeWindows.remove(window)
            windowDelegates.removeValue(forKey: window)
            logger.info("Window closed successfully")
        }
    }

    func saveWindowStatesOnQuit() {
        if saveWindowsOnQuit {
            windowServices.saveWindowStates()
        }
    }

    func restoreWindowStates() {
        if layoutManager.shouldApplyLayoutOnLaunch(),
            let activeLayout = layoutManager.getActiveLayout()
        {
            applyLayout(activeLayout)
            return
        }

        /// Fallback to standard window restoration
        var restoredCount: Int = 0

        do {
            guard windowServices.validateStoredState() else {
                throw WindowManagerError.windowRestoreValidationFailed
            }

            windowServices.restoreWindows { [weak self] frame in
                guard let self = self else { return }
                do {
                    try createPreviewWindow(at: frame)
                    restoredCount += 1
                    logger.debug("Restored window \(restoredCount)")
                } catch {
                    logger.logError(error, context: "Failed to restore window \(restoredCount + 1)")
                }
            }
        } catch {
            logger.logError(error, context: "Window state restoration failed")
        }

        handleRestoreCompletion(restoredCount)
    }

    func applyLayout(_ layout: Layout) {
        logger.info("Applying window layout: '\(layout.name)'")

        closeAllWindows()

        windowServices.windowStorage.restoreSpecificWindows(layout.windows) { [weak self] frame in
            guard let self = self else { return }
            do {
                try createPreviewWindow(at: frame)
            } catch {
                logger.logError(
                    error, context: "Failed to create window from layout '\(layout.name)'")
            }
        }
    }

    func saveCurrentLayoutAsLayout(name: String) -> Layout {
        let layout = layoutManager.createLayout(name: name)
        return layout
    }

    // MARK: - Private Methods

    private func createDefaultWindow() {
        do {
            try createPreviewWindow()
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
            onClose: { [weak self, weak window] in
                guard let window = window else { return }
                self?.closeWindow(window)
            }
        )
        window.contentView = NSHostingView(rootView: contentView)
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

// MARK: - Supporting Types

enum WindowManagerError: LocalizedError {
    case windowCreationFailed
    case invalidScreenConfiguration
    case windowRestoreValidationFailed
    case windowValidationFailed

    var errorDescription: String? {
        switch self {
        case .windowCreationFailed:
            return "Failed to create window with valid configuration"
        case .invalidScreenConfiguration:
            return "No valid screen configuration available"
        case .windowRestoreValidationFailed:
            return "Window restore state validation failed"
        case .windowValidationFailed:
            return "Window state validation failed"
        }
    }
}
