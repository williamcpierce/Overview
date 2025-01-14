/*
 Window/Services/WindowConfigurationService.swift
 Overview

 Created by William Pierce on 1/13/25.

 Manages window configuration and style application, separating window
 creation logic from management concerns.
*/

import SwiftUI

final class WindowConfigurationService {
    // Constants
    private struct Constants {
        static let statusBarOffset: Int = 1

        struct Window {
            static let defaultStyleMask: NSWindow.StyleMask = .fullSizeContentView
            static let defaultBackgroundColor: NSColor = .clear
            static let defaultIsMovable: Bool = true
        }
    }

    // Dependencies
    private let logger = AppLogger.interface

    func createWindow(with frame: NSRect) throws -> NSWindow {
        let config = WindowConfiguration.default

        let window = NSWindow(
            contentRect: frame,
            styleMask: config.styleMask,
            backing: config.backing,
            defer: config.deferCreation
        )

        guard validateWindow(window) else {
            logger.error("Window creation failed: invalid window state")
            throw WindowManagerError.windowCreationFailed
        }

        return window
    }

    func applyConfiguration(
        to window: NSWindow,
        hasShadow: Bool,
        level: NSWindow.Level = .statusBar + Constants.statusBarOffset
    ) {
        window.hasShadow = hasShadow
        window.backgroundColor = Constants.Window.defaultBackgroundColor
        window.isMovableByWindowBackground = Constants.Window.defaultIsMovable
        window.level = level
    }

    func updateResizability(_ window: NSWindow, isEditable: Bool) {
        var newStyleMask: NSWindow.StyleMask = Constants.Window.defaultStyleMask

        if isEditable {
            newStyleMask.insert(.resizable)
        }

        guard window.styleMask != newStyleMask else { return }

        window.styleMask = newStyleMask
        logger.debug("Window resizability updated: editable=\(isEditable)")
    }

    func updateMovability(_ window: NSWindow, isMovable: Bool) {
        guard window.isMovable != isMovable else { return }

        window.isMovable = isMovable
        logger.debug("Window movability updated: movable=\(isMovable)")
    }

    func updateMissionControl(_ window: NSWindow, isManaged: Bool) {
        let currentlyManaged: Bool = window.collectionBehavior.contains(.managed)

        guard isManaged != currentlyManaged else { return }

        if isManaged {
            window.collectionBehavior.insert(.managed)
        } else {
            window.collectionBehavior.remove(.managed)
        }

        logger.debug("Mission Control management updated: managed=\(isManaged)")
    }

    // MARK: - Private Methods

    private func validateWindow(_ window: NSWindow) -> Bool {
        window.contentView != nil && window.frame.size.width > 0 && window.frame.size.height > 0
    }
}
