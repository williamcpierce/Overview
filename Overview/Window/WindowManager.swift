/*
 Window/WindowManager.swift
 Overview

 Created by William Pierce on 1/12/25.

 Coordinates window lifecycle management and state persistence.
*/

import SwiftUI

@MainActor
final class WindowManager {
    // Dependencies
    private var previewManager: PreviewManager
    private var sourceManager: SourceManager
    private var permissionManager: PermissionManager
    private let windowStorage: WindowStorage = WindowStorage.shared
    private let configService = WindowServices.shared.windowConfiguration
    private let positionService = WindowServices.shared.windowPosition
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

    init(
        previewManager: PreviewManager,
        sourceManager: SourceManager,
        permissionManager: PermissionManager
    ) {
        self.previewManager = previewManager
        self.sourceManager = sourceManager
        self.permissionManager = permissionManager
        self.sessionWindowCounter = 0
        logger.debug("Window manager initialized")
    }

    // MARK: - Window Management

    func createPreviewWindow(at frame: NSRect? = nil) throws {
        do {
            let initialFrame =
                try frame
                ?? positionService.createDefaultFrame(
                    defaultWidth: defaultWidth,
                    defaultHeight: defaultHeight,
                    windowCount: sessionWindowCounter
                )
            let validatedFrame = initialFrame.ensureOnScreen()

            logFrameAdjustment(initial: initialFrame, validated: validatedFrame)

            let window = try configService.createWindow(with: validatedFrame)
            configureWindow(window)

            activeWindows.insert(window)
            sessionWindowCounter += 1

            window.orderFront(nil)
            logger.info("Created new preview window: id=\(sessionWindowCounter)")
        } catch {
            logger.logError(error, context: "Failed to create preview window")
            throw WindowManagerError.windowCreationFailed
        }
    }

    func closeWindow(_ window: NSWindow) {
        Task {
            logger.debug("Initiating window closure")
            window.orderOut(nil)
            activeWindows.remove(window)
            windowDelegates.removeValue(forKey: window)
            logger.info("Window closed successfully")
        }
    }

    // MARK: - State Management

    func saveWindowStates() {
        windowStorage.saveWindowStates()
    }

    func restoreWindowStates() {
        var restoredCount = 0

        do {
            guard windowStorage.validateStoredState() else {
                throw WindowManagerError.windowRestoreValidationFailed
            }

            windowStorage.restoreWindows { [weak self] frame in
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

    // MARK: - Private Methods

    private func logFrameAdjustment(initial: NSRect, validated: NSRect) {
        if validated != initial {
            logger.debug(
                """
                Window frame adjusted:
                initial=(\(Int(initial.origin.x)), \(Int(initial.origin.y)), \
                \(Int(initial.size.width)), \(Int(initial.size.height)))
                validated=(\(Int(validated.origin.x)), \(Int(validated.origin.y)), \
                \(Int(validated.size.width)), \(Int(validated.size.height)))
                """)
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

    // MARK: - Private Methods

    private func createDefaultWindow() {
        do {
            try createPreviewWindow()
        } catch {
            logger.logError(error, context: "Failed to create default window")
        }
    }

    private func configureWindow(_ window: NSWindow) {
        configService.applyConfiguration(to: window, hasShadow: shadowEnabled)
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
