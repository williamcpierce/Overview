/*
 Preview/PreviewAccessor.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages window configuration and layout for preview windows,
 handling resizing, aspect ratio maintenance, and window behavior.
*/

import SwiftUI

struct PreviewAccessor: NSViewRepresentable {
    // MARK: - Dependancies
    @Binding var aspectRatio: CGFloat
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var captureManager: CaptureManager
    @ObservedObject var previewManager: PreviewManager
    private let logger = AppLogger.windows

    // MARK: - Constants
    private let resizeThrottleInterval: TimeInterval = 0.1

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            guard let window: NSWindow = view.window else {
                logger.warning("Window reference unavailable during initialization")
                return
            }

            configureWindowDefaults(window)
            logger.info(
                "Window initialized: \(Int(window.frame.width))x\(Int(window.frame.height))")
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window: NSWindow = nsView.window else {
            logger.debug("Window reference unavailable during update")
            return
        }

        synchronizeWindowConfiguration(window)

        DispatchQueue.main.asyncAfter(deadline: .now() + resizeThrottleInterval) {
            synchronizeAspectRatio(window)
        }
    }

    // MARK: - Window Configuration

    private func configureWindowDefaults(_ window: NSWindow) {
        window.backgroundColor = .clear
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.styleMask = NSWindow.StyleMask.fullSizeContentView

        logger.debug("Applied default window configuration")
    }

    private func synchronizeWindowConfiguration(_ window: NSWindow) {
        let previousLevel: NSWindow.Level = window.level

        updateEditModeState(window)
        updateWindowLevel(window)
        updateMissionControlBehavior(window)

        if window.level != previousLevel {
            logger.info("Window level changed: \(window.level.rawValue)")
        }
    }

    private func updateEditModeState(_ window: NSWindow) {
        let newStyleMask: NSWindow.StyleMask =
            previewManager.editModeEnabled
            ? [.fullSizeContentView, .resizable]
            : .fullSizeContentView

        if window.styleMask != newStyleMask {
            window.styleMask = newStyleMask
            window.isMovable = previewManager.editModeEnabled
            logger.debug("Edit mode state updated: \(previewManager.editModeEnabled)")
        }
    }

    private func updateWindowLevel(_ window: NSWindow) {
        let shouldFloat: Bool =
            previewManager.editModeEnabled && appSettings.enableEditModeAlignment
        let newLevel: NSWindow.Level = shouldFloat ? .floating : .statusBar + 1

        if window.level != newLevel {
            window.level = newLevel
            logger.debug("Window level updated: floating=\(shouldFloat)")
        }
    }

    private func updateMissionControlBehavior(_ window: NSWindow) {
        let shouldManage: Bool = appSettings.managedByMissionControl

        if shouldManage {
            window.collectionBehavior.insert(.managed)
        } else {
            window.collectionBehavior.remove(.managed)
        }

        logger.debug("Mission Control behavior updated: managed=\(shouldManage)")
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
