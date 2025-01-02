/*
 Preview/PreviewAccessor.swift
 Overview

 Created by William Pierce on 9/15/24.
*/

import SwiftUI

struct PreviewAccessor: NSViewRepresentable {
    @Binding var aspectRatio: CGFloat
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var captureManager: CaptureManager
    @ObservedObject var previewManager: PreviewManager
    private let logger = AppLogger.windows
    private let resizeThrottleInterval: TimeInterval = 0.1

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            guard let window: NSWindow = view.window else {
                logger.warning("No window reference available during setup")
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
            logger.warning("No window reference available during update")
            return
        }

        synchronizeWindowConfiguration(window)

        DispatchQueue.main.asyncAfter(deadline: .now() + resizeThrottleInterval) {
            synchronizeAspectRatio(window)
        }
    }

    private func configureWindowDefaults(_ window: NSWindow) {
        window.styleMask = [.fullSizeContentView]
        window.hasShadow = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.collectionBehavior.insert(.fullScreenAuxiliary)
    }

    private func synchronizeWindowConfiguration(_ window: NSWindow) {
        updateEditModeState(window)
        updateWindowLevel(window)
        updateMissionControlBehavior(window)
    }

    private func updateEditModeState(_ window: NSWindow) {
        window.styleMask =
            previewManager.editModeEnabled
            ? [.fullSizeContentView, .resizable] : [.fullSizeContentView]
        window.isMovable = previewManager.editModeEnabled
    }

    private func updateWindowLevel(_ window: NSWindow) {
        let shouldFloat: Bool =
            previewManager.editModeEnabled && appSettings.enableEditModeAlignment
        window.level = shouldFloat ? .floating : .statusBar + 1
    }

    private func updateMissionControlBehavior(_ window: NSWindow) {
        if appSettings.managedByMissionControl {
            window.collectionBehavior.insert(.managed)
        } else {
            window.collectionBehavior.remove(.managed)
        }
    }

    private func synchronizeAspectRatio(_ window: NSWindow) {
        guard captureManager.isCapturing else { return }

        let windowWidth: CGFloat = window.frame.width
        let windowHeight: CGFloat = window.frame.height
        let desiredHeight: CGFloat = windowWidth / aspectRatio

        let heightDifference: CGFloat = abs(windowHeight - desiredHeight)
        guard heightDifference > 1.0 else { return }

        let updatedSize = NSSize(width: windowWidth, height: desiredHeight)
        window.setContentSize(updatedSize)
        window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)

        logger.debug("Window resized: \(Int(updatedSize.width))x\(Int(updatedSize.height))")
    }
}
