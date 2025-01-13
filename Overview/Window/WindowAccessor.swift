/*
 Window/WindowAccessor.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    // Constants
    private struct Constants {
        static let throttleInterval: TimeInterval = 0.1
        static let minHeightDifference: CGFloat = 1.0
        static let statusBarOffset: Int = 1

        struct Window {
            static let defaultStyleMask: NSWindow.StyleMask = .fullSizeContentView
            static let defaultLevel: NSWindow.Level = .statusBar + 1
            static let floatingLevel: NSWindow.Level = .floating
        }
    }

    // Dependencies
    @Binding var aspectRatio: CGFloat
    @ObservedObject var captureManager: CaptureManager
    @ObservedObject var previewManager: PreviewManager
    @ObservedObject var sourceManager: SourceManager
    private let logger = AppLogger.interface

    // Window Settings
    @AppStorage(WindowSettingsKeys.managedByMissionControl)
    private var managedByMissionControl = WindowSettingsKeys.defaults.managedByMissionControl
    @AppStorage(WindowSettingsKeys.shadowEnabled)
    private var shadowEnabled = WindowSettingsKeys.defaults.shadowEnabled

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        logger.debug("Created window accessor view")
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = validateWindowState(nsView) else { return }

        DispatchQueue.main.async {
            synchronizeWindowState(window)
        }
    }

    // MARK: - Private Methods

    private func validateWindowState(_ view: NSView) -> NSWindow? {
        guard view.window != nil, view.superview != nil else {
            logger.debug("Invalid window state detected")
            return nil
        }
        return view.window
    }

    private func synchronizeWindowState(_ window: NSWindow) {
        updateResizability(window)
        updateMovability(window)
        updateLevel(window)
        updateShadow(window)

        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.throttleInterval) {
            updateAspectRatio(window)
            updateMissionControl(window)
        }
    }

    private func updateResizability(_ window: NSWindow) {
        var newStyleMask: NSWindow.StyleMask = Constants.Window.defaultStyleMask

        if previewManager.editModeEnabled {
            newStyleMask.insert(.resizable)
        }

        guard window.styleMask != newStyleMask else { return }

        window.styleMask = newStyleMask
        logger.debug("Window resizability updated: editable=\(previewManager.editModeEnabled)")
    }

    private func updateMovability(_ window: NSWindow) {
        let newMovability = previewManager.editModeEnabled

        guard window.isMovable != newMovability else { return }

        window.isMovable = newMovability
        logger.debug("Window movability updated: movable=\(newMovability)")
    }

    private func updateLevel(_ window: NSWindow) {
        let shouldFloat = previewManager.editModeEnabled && sourceManager.isOverviewActive
        let newLevel: NSWindow.Level =
            shouldFloat ? Constants.Window.floatingLevel : Constants.Window.defaultLevel

        guard window.level != newLevel else { return }

        window.level = newLevel
        logger.debug("Window level updated: floating=\(shouldFloat)")
    }

    private func updateShadow(_ window: NSWindow) {
        guard window.hasShadow != shadowEnabled else { return }

        window.hasShadow = shadowEnabled
        logger.debug("Window shadow updated: \(shadowEnabled ? "Enabled" : "Disabled")")
    }

    private func updateMissionControl(_ window: NSWindow) {
        let currentlyManaged: Bool = window.collectionBehavior.contains(.managed)

        guard managedByMissionControl != currentlyManaged else { return }

        if managedByMissionControl {
            window.collectionBehavior.insert(.managed)
        } else {
            window.collectionBehavior.remove(.managed)
        }

        logger.debug("Mission Control management updated: managed=\(managedByMissionControl)")
    }

    private func updateAspectRatio(_ window: NSWindow) {
        guard captureManager.isCapturing,
            aspectRatio != 0,
            let adjustedSize: NSSize = calculateAdjustedSize(for: window)
        else {
            return
        }

        window.setContentSize(adjustedSize)
        window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)

        logger.info("Window resized: \(Int(adjustedSize.width))x\(Int(adjustedSize.height))")
    }

    private func calculateAdjustedSize(for window: NSWindow) -> NSSize? {
        let windowWidth: CGFloat = window.frame.width
        let windowHeight: CGFloat = window.frame.height
        let desiredHeight: CGFloat = windowWidth / aspectRatio

        let heightDifference: CGFloat = abs(windowHeight - desiredHeight)
        guard heightDifference > Constants.minHeightDifference else { return nil }

        return NSSize(width: windowWidth, height: desiredHeight)
    }
}
