/*
 Window/WindowManager.swift
 Overview

 Created by William Pierce on 1/5/25.

 Manages the creation, configuration, and lifecycle of preview windows,
 coordinating window state persistence and restoration.
*/

import SwiftUI

// MARK: - Types

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

final class WindowManager {
    // MARK: - Constants
    
    private struct Constants {
        static let cascadeOffset: CGFloat = 25
        static let fallbackPosition: CGFloat = 100
        static let statusBarOffset: Int = 1
        static let minimumWindowDimension: CGFloat = 100
        
        struct Window {
            static let defaultBackgroundColor: NSColor = .clear
            static let defaultHasShadow: Bool = false
            static let defaultIsMovable: Bool = true
        }
    }
    
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

    // MARK: - Initialization
    
    init(appSettings: AppSettings, previewManager: PreviewManager, sourceManager: SourceManager) {
        self.appSettings = appSettings
        self.previewManager = previewManager
        self.sourceManager = sourceManager
        self.sessionWindowCounter = 0
        logger.debug("Window manager initialized")
    }

    deinit {
        cleanupResources()
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
            
            handleRestoreCompletion(restoredCount)
        } catch {
            logger.logError(error, context: "Window state restoration failed")
            createDefaultWindow()
        }
    }

    // MARK: - Private Methods
    
    private func cleanupResources() {
        windowDelegates.removeAll()
        activeWindows.removeAll()
        logger.debug("Window manager resources cleaned up")
    }
    
    private func logFrameAdjustment(initial: NSRect, validated: NSRect) {
        if validated != initial {
            logger.debug("""
                Window frame adjusted:
                initial=(\(Int(initial.origin.x)), \(Int(initial.origin.y)), \
                \(Int(initial.size.width)), \(Int(initial.size.height)))
                validated=(\(Int(validated.origin.x)), \(Int(validated.origin.y)), \
                \(Int(validated.size.width)), \(Int(validated.size.height)))
                """)
        }
    }
    
    private func handleRestoreCompletion(_ restoredCount: Int) {
        if restoredCount == 0 {
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
            width: max(appSettings.windowDefaultWidth, Constants.minimumWindowDimension),
            height: max(appSettings.windowDefaultHeight, Constants.minimumWindowDimension)
        )
        
        logger.debug("Created fallback frame: \(frame.size.width)x\(frame.size.height)")
        return frame
    }
    
    private func calculateCenteredFrame(in visibleFrame: NSRect) -> NSRect {
        let defaultWidth = max(appSettings.windowDefaultWidth, Constants.minimumWindowDimension)
        let defaultHeight = max(appSettings.windowDefaultHeight, Constants.minimumWindowDimension)
        
        let centerX = visibleFrame.minX + (visibleFrame.width - defaultWidth) / 2
        let centerY = visibleFrame.minY + (visibleFrame.height - defaultHeight) / 2
        
        let offset = CGFloat(sessionWindowCounter) * Constants.cascadeOffset
        
        let frame = NSRect(
            x: centerX + offset,
            y: centerY - offset,
            width: defaultWidth,
            height: defaultHeight
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
        
        // Check basic window state instead of non-existent isValid
        guard window.contentView != nil,
              window.frame.size.width > 0,
              window.frame.size.height > 0 else {
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
            appSettings: appSettings,
            previewManager: previewManager,
            sourceManager: sourceManager
        )
        window.contentView = NSHostingView(rootView: contentView)
    }
    
    private func validateWindowStates() throws {
        let invalidWindows = activeWindows.filter { window in
            guard window.contentView != nil,
                  window.frame.size.width > 0,
                  window.frame.size.height > 0,
                  NSWindow.windowNumbers()?.contains(NSNumber(value: window.windowNumber)) == true else {
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
