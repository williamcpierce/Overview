/*
 Window/Services/WindowConfigurationService.swift
 Overview

 Created by William Pierce on 1/13/25.

 Manages window configuration and style application, separating window
 creation logic from management concerns.
*/

import Defaults
import SwiftUI

@MainActor
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
            logger.error("Window creation failed: invalid window")
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
        // Apply early so the first drag onto a fullscreen-game display is allowed.
        updateSpaceParticipation(window, joinsAllDesktops: Defaults[.assignPreviewsToAllDesktops])
        updateMissionControl(window, isManaged: Defaults[.managedByMissionControl])
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

    /// Lets previews sit on every Space, including a display running a fullscreen game.
    func updateSpaceParticipation(_ window: NSWindow, joinsAllDesktops: Bool) {
        var behavior = window.collectionBehavior
        // Never become the fullscreen primary — these are always auxiliary overlays.
        behavior.remove(.fullScreenPrimary)
        if joinsAllDesktops {
            behavior.insert(.canJoinAllSpaces)
            behavior.insert(.fullScreenAuxiliary)
        } else {
            behavior.remove(.canJoinAllSpaces)
            behavior.remove(.fullScreenAuxiliary)
        }
        guard window.collectionBehavior != behavior else { return }
        window.collectionBehavior = behavior
        logger.debug("Space participation updated: joinsAllDesktops=\(joinsAllDesktops)")
    }

    // MARK: - Private Methods

    private func validateWindow(_ window: NSWindow) -> Bool {
        window.contentView != nil && window.frame.size.width > 0 && window.frame.size.height > 0
    }
}

// MARK: - Supporting Types

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
