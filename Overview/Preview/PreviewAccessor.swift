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
        logger.info("Creating window container view")
        let view = NSView()

        DispatchQueue.main.async {
            guard let window = view.window else {
                logger.warning("No window reference available during setup")
                return
            }

            configureWindowDefaults(window)
            configureWindowSize(window)
            logger.info(
                "Window initialized with size: \(window.frame.width)x\(window.frame.height)")
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else {
            logger.warning("No window reference available during update")
            return
        }

        window.styleMask =
            editModeEnabled ? [.fullSizeContentView, .resizable] : [.fullSizeContentView]
        window.isMovable = editModeEnabled
        window.level =
            editModeEnabled && appSettings.enableEditModeAlignment ? .floating : .statusBar + 1

        if appSettings.managedByMissionControl {
            window.collectionBehavior.insert(.managed)
        } else {
            window.collectionBehavior.remove(.managed)
        }

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

    private func synchronizeAspectRatio(_ window: NSWindow) {
        let currentSize = window.frame.size
        let targetHeight = currentSize.width / aspectRatio

        let heightDifference = abs(currentSize.height - targetHeight)
        guard heightDifference > 1.0 else { return }

        let newSize = NSSize(width: currentSize.width, height: targetHeight)
        window.setContentSize(newSize)
        window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)

        logger.debug(
            """
            Window size updated: \(String(format: "%.1f", currentSize.width))x\
            \(String(format: "%.1f", targetHeight)) (ratio: \
            \(String(format: "%.2f", aspectRatio)))
            """
        )
    }
}
