/*
 Window/WindowManager.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import SwiftUI

@MainActor
final class WindowManager {
    // Constants
    private struct Constants {
        static let cascadeOffset: CGFloat = 25
        static let fallbackPosition: CGFloat = 100
        static let statusBarOffset: Int = 1
        static let minWidth: CGFloat = 180
        static let minHeight: CGFloat = 60

        struct Window {
            static let defaultBackgroundColor: NSColor = .clear
            static let defaultHasShadow: Bool = true
            static let defaultIsMovable: Bool = true
        }
    }

    // Dependencies
    private var previewManager: PreviewManager
    private var sourceManager: SourceManager
    private let windowStorage: WindowStorage = WindowStorage.shared
    private let logger = AppLogger.interface

    // Private State
    private var activeWindows: Set<NSWindow> = []
    private var windowDelegates: [NSWindow: WindowDelegate] = [:]
    private var sessionWindowCounter: Int

    // Window Settings
    @AppStorage(WindowSettingsKeys.defaultWidth)
    private var defaultWidth = WindowSettingsKeys.defaults.defaultWidth
    @AppStorage(WindowSettingsKeys.defaultHeight)
    private var defaultHeight = WindowSettingsKeys.defaults.defaultHeight
    @AppStorage(WindowSettingsKeys.createOnLaunch)
    private var createOnLaunch = WindowSettingsKeys.defaults.createOnLaunch

    // MARK: - Initialization

    init(previewManager: PreviewManager, sourceManager: SourceManager) {
        self.previewManager = previewManager
        self.sourceManager = sourceManager
        self.sessionWindowCounter = 0
        logger.debug("Window manager initialized")
    }

    deinit {
        //        cleanupResources()
    }

    // MARK: - Window Management

    func createPreviewWindow(at frame: NSRect? = nil) throws {
        do {
            let initialFrame = try frame ?? createDefaultFrame()
            let validatedFrame = initialFrame.ensureOnScreen()

            logFrameAdjustment(initial: initialFrame, validated: validatedFrame)

            let window = try createConfiguredWindow(with: validatedFrame)
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

    // MARK: - State Management

    func saveWindowStates() {
        do {
            try validateWindowStates()
            windowStorage.saveWindowStates()
            logger.info("Saved state for \(activeWindows.count) windows")
        } catch {
            logger.logError(error, context: "Failed to save window states")
        }
    }

    func restoreWindowStates() {
        var restoredCount = 0

        do {
            guard windowStorage.validateStoredState() else {
                throw WindowManagerError.windowRestoreValidationFailed
            }

            windowStorage.restoreWindows { [self] frame in
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

    private func cleanupResources() {
        windowDelegates.removeAll()
        activeWindows.removeAll()
        logger.debug("Window manager resources cleaned up")
    }

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

    private func createDefaultWindow() {
        do {
            try createPreviewWindow()
        } catch {
            logger.logError(error, context: "Failed to create default window")
        }
    }

    private func createDefaultFrame() throws -> NSRect {
        guard let screen = NSScreen.main else {
            logger.warning("No main screen detected, using fallback dimensions")
            return createFallbackFrame()
        }

        return calculateCenteredFrame(in: screen.visibleFrame)
    }

    private func createFallbackFrame() -> NSRect {
        let frame = NSRect(
            x: Constants.fallbackPosition,
            y: Constants.fallbackPosition,
            width: max(defaultWidth, Constants.minWidth),
            height: max(defaultHeight, Constants.minHeight)
        )

        logger.debug("Created fallback frame: \(frame.size.width)x\(frame.size.height)")
        return frame
    }

    private func calculateCenteredFrame(in visibleFrame: NSRect) -> NSRect {
        let width = max(defaultWidth, Constants.minWidth)
        let height = max(defaultHeight, Constants.minHeight)

        let centerX = visibleFrame.minX + (visibleFrame.width - width) / 2
        let centerY = visibleFrame.minY + (visibleFrame.height - height) / 2

        let offset = CGFloat(sessionWindowCounter) * Constants.cascadeOffset

        let frame = NSRect(
            x: centerX + offset,
            y: centerY - offset,
            width: width,
            height: height
        )

        return frame.ensureOnScreen()
    }

    private func createConfiguredWindow(with frame: NSRect) throws -> NSWindow {
        let config = WindowConfiguration.default

        let window = NSWindow(
            contentRect: frame,
            styleMask: config.styleMask,
            backing: config.backing,
            defer: config.deferCreation
        )

        guard window.contentView != nil,
            window.frame.size.width > 0,
            window.frame.size.height > 0
        else {
            logger.error("Window creation failed: invalid window state")
            throw WindowManagerError.windowCreationFailed
        }

        return window
    }

    private func configureWindow(_ window: NSWindow) {
        applyWindowStyle(to: window)
        setupWindowDelegate(for: window)
        setupWindowContent(window)
    }

    private func applyWindowStyle(to window: NSWindow) {
        window.backgroundColor = Constants.Window.defaultBackgroundColor
        window.hasShadow = Constants.Window.defaultHasShadow
        window.isMovableByWindowBackground = Constants.Window.defaultIsMovable
        window.level = .statusBar + Constants.statusBarOffset
    }

    private func setupWindowDelegate(for window: NSWindow) {
        let delegate = WindowDelegate(windowManager: self)
        windowDelegates[window] = delegate
        window.delegate = delegate
        logger.debug("Window delegate configured: id=\(sessionWindowCounter)")
    }

    private func setupWindowContent(_ window: NSWindow) {
        let contentView = ContentView(
            previewManager: previewManager,
            sourceManager: sourceManager
        )
        window.contentView = NSHostingView(rootView: contentView)
    }

    private func validateWindowStates() throws {
        let invalidWindows = activeWindows.filter { window in
            guard window.contentView != nil,
                window.frame.size.width > 0,
                window.frame.size.height > 0
            else {
                return true
            }
            return false
        }

        if !invalidWindows.isEmpty {
            logger.warning("Detected \(invalidWindows.count) invalid windows")
            throw WindowManagerError.windowValidationFailed
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

struct WindowConfiguration {
    let frame: NSRect
    let styleMask: NSWindow.StyleMask
    let backing: NSWindow.BackingStoreType
    let deferCreation: Bool

    static let `default` = WindowConfiguration(
        frame: .zero,
        styleMask: [.fullSizeContentView],
        backing: .buffered,
        deferCreation: false
    )
}
