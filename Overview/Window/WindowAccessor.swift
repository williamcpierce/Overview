/*
 Window/WindowAccessor.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages window configuration and layout for preview windows,
 handling resizing, aspect ratio maintenance, and window behavior.
*/

import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    // MARK: - Constants

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

    // MARK: - Dependencies

    @Binding var aspectRatio: CGFloat
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var captureManager: CaptureManager
    @ObservedObject var previewManager: PreviewManager
    private let logger = AppLogger.interface

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
        synchronizeEditableState(window)

        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.throttleInterval) {
            synchronizeLayoutAndBehavior(window)
        }
    }

    private func synchronizeLayoutAndBehavior(_ window: NSWindow) {
        synchronizeAspectRatio(window)
        synchronizeBehavior(window)
    }

    private func synchronizeEditableState(_ window: NSWindow) {
        updateResizability(window)
        updateMovability(window)
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

    private func synchronizeBehavior(_ window: NSWindow) {
        updateLevel(window)
        updateMissionControl(window)
    }

    private func updateLevel(_ window: NSWindow) {
        let shouldFloat = previewManager.editModeEnabled && appSettings.windowAlignmentEnabled
        let newLevel: NSWindow.Level =
            shouldFloat ? Constants.Window.floatingLevel : Constants.Window.defaultLevel

        guard window.level != newLevel else { return }

        window.level = newLevel
        logger.debug("Window level updated: floating=\(shouldFloat)")
    }

    private func updateMissionControl(_ window: NSWindow) {
        let shouldManage = appSettings.windowManagedByMissionControl
        let currentlyManaged: Bool = window.collectionBehavior.contains(.managed)

        guard shouldManage != currentlyManaged else { return }

        if shouldManage {
            window.collectionBehavior.insert(.managed)
        } else {
            window.collectionBehavior.remove(.managed)
        }

        logger.debug("Mission Control management updated: managed=\(shouldManage)")
    }

    private func synchronizeAspectRatio(_ window: NSWindow) {
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
