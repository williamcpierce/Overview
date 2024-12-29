/*
 Preview/PreviewAccessor.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages low-level window configuration through NSWindow APIs, providing a bridge
 between SwiftUI window state and AppKit window behavior for Overview's previews.
*/

import SwiftUI

struct PreviewAccessor: NSViewRepresentable {
    @ObservedObject var appSettings: AppSettings
    @Binding var aspectRatio: CGFloat
    @Binding var editModeEnabled: Bool

    private let logger = AppLogger.windows
    private let resizeThrottleInterval: TimeInterval = 0.1

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            guard let window = view.window else {
                logger.warning("No window reference available during setup")
                return
            }

            configureWindowDefaults(window)
            configureWindowSize(window)

            logger.info(
                "Window initialized: \(Int(window.frame.width))x\(Int(window.frame.height))")
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else {
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

    private func configureWindowSize(_ window: NSWindow) {
        let size = NSSize(
            width: appSettings.defaultWindowWidth,
            height: appSettings.defaultWindowHeight
        )
        window.setContentSize(size)
        window.contentMinSize = size
        window.contentAspectRatio = size
    }

    private func synchronizeWindowConfiguration(_ window: NSWindow) {
        updateEditModeState(window)
        updateWindowLevel(window)
        updateMissionControlBehavior(window)
    }

    private func updateEditModeState(_ window: NSWindow) {
        window.styleMask =
            editModeEnabled ? [.fullSizeContentView, .resizable] : [.fullSizeContentView]
        window.isMovable = editModeEnabled
    }

    private func updateWindowLevel(_ window: NSWindow) {
        let shouldFloat = editModeEnabled && appSettings.enableEditModeAlignment
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
        let windowWidth = window.frame.width
        let windowHeight = window.frame.height
        let desiredHeight = windowWidth / aspectRatio

        let heightDifference = abs(windowHeight - desiredHeight)
        guard heightDifference > 1.0 else { return }

        let updatedSize = NSSize(width: windowWidth, height: desiredHeight)
        window.setContentSize(updatedSize)
        window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)

        logger.debug("Window resized: \(Int(updatedSize.width))x\(Int(updatedSize.height))")
    }
}
