/*
 Window/WindowAccessor.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages window configuration and layout for preview windows,
 handling resizing, aspect ratio maintenance, and window behavior.
*/

import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    // MARK: - Dependencies
    @Binding var aspectRatio: CGFloat
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var captureManager: CaptureManager
    @ObservedObject var previewManager: PreviewManager
    private let logger = AppLogger.interface

    // MARK: - Constants
    private let throttleInterval: TimeInterval = 0.1

    func makeNSView(context: Context) -> NSView {
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard nsView.window != nil, nsView.superview != nil else {
            return
        }

        DispatchQueue.main.async {
            guard let window: NSWindow = nsView.window else { return }
            synchronizeEditableState(window)

            DispatchQueue.main.asyncAfter(deadline: .now() + throttleInterval) {
                guard nsView.window != nil, nsView.superview != nil else { return }
                synchronizeAspectRatio(window)
                synchronizeBehavior(window)
            }
        }
    }

    // MARK: - Editable State Management

    private func synchronizeEditableState(_ window: NSWindow) {
        updateResizability(window)
        updateMovability(window)
    }

    private func updateResizability(_ window: NSWindow) {
        var newStyleMask: NSWindow.StyleMask = .fullSizeContentView

        if previewManager.editModeEnabled {
            newStyleMask.insert(.resizable)
        }
        if window.styleMask != newStyleMask {
            window.styleMask = newStyleMask
            logger.debug("Window resizability updated")
        }
    }

    private func updateMovability(_ window: NSWindow) {
        let newMovability: Bool = previewManager.editModeEnabled
        if window.isMovable != newMovability {
            window.isMovable = newMovability
            logger.debug("Window movability updated")
        }
    }

    // MARK: - Behavior Management

    private func synchronizeBehavior(_ window: NSWindow) {
        updateLevel(window)
        updateMissionControl(window)
        updateShadow(window)
    }

    private func updateLevel(_ window: NSWindow) {
        let shouldFloat = previewManager.editModeEnabled && appSettings.windowAlignmentEnabled
        let newLevel: NSWindow.Level = shouldFloat ? .floating : .statusBar + 1

        if window.level != newLevel {
            window.level = newLevel
            logger.debug("Window level updated: floating=\(shouldFloat)")
        }
    }

    private func updateShadow(_ window: NSWindow) {
        let enableShadow = appSettings.windowShadowEnabled  // Assuming this is a setting in AppSettings

        window.hasShadow = enableShadow
        logger.debug("Window shadow updated: \(enableShadow ? "Enabled" : "Disabled")")
    }

    private func updateMissionControl(_ window: NSWindow) {
        let shouldManage = appSettings.windowManagedByMissionControl

        if shouldManage {
            guard !window.collectionBehavior.contains(.managed) else { return }
            window.collectionBehavior.insert(.managed)
        } else {
            guard window.collectionBehavior.contains(.managed) else { return }
            window.collectionBehavior.remove(.managed)
        }

        logger.debug("Mission Control management updated: managed=\(shouldManage)")
    }

    // MARK: - Layout Management

    private func synchronizeAspectRatio(_ window: NSWindow) {
        guard captureManager.isCapturing else { return }
        guard aspectRatio != 0 else { return }

        let windowWidth: CGFloat = window.frame.width
        let windowHeight: CGFloat = window.frame.height
        let desiredHeight: CGFloat = windowWidth / aspectRatio

        let heightDifference: CGFloat = abs(windowHeight - desiredHeight)
        guard heightDifference > 1.0 else { return }

        let updatedSize = NSSize(width: windowWidth, height: desiredHeight)
        window.setContentSize(updatedSize)
        window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)

        logger.info("Window resized: \(Int(updatedSize.width))x\(Int(updatedSize.height))")
    }
}
