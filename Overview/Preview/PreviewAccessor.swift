/*
 PreviewAccessor.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages low-level window configuration through NSWindow APIs, providing a bridge
 between SwiftUI window state and AppKit window behavior for Overview's previews.
*/

import SwiftUI

struct PreviewAccessor: NSViewRepresentable {
    @Binding var aspectRatio: CGFloat
    @Binding var isEditModeEnabled: Bool
    @ObservedObject var appSettings: AppSettings

    private let resizeThrottleInterval: TimeInterval = 0.1

    func makeNSView(context: Context) -> NSView {
        AppLogger.windows.debug("Creating window container view")
        let view = NSView()

        DispatchQueue.main.async {
            guard let window = view.window else {
                AppLogger.windows.warning("No window reference available during setup")
                return
            }

            configureWindowDefaults(window)
            configureWindowSize(window)

            AppLogger.windows.info(
                "Window initialized with size: \(window.frame.width)x\(window.frame.height)")
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else {
            AppLogger.windows.warning("No window reference available during update")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + resizeThrottleInterval) {
            synchronizeWindowConfiguration(window)
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
        synchronizeEditModeState(window)
        synchronizeMissionControlBehavior(window)
        synchronizeAspectRatio(window)
    }

    private func synchronizeEditModeState(_ window: NSWindow) {
        AppLogger.windows.debug("Updating edit mode properties: isEnabled=\(isEditModeEnabled)")

        window.styleMask =
            isEditModeEnabled ? [.fullSizeContentView, .resizable] : [.fullSizeContentView]
        window.isMovable = isEditModeEnabled

        window.level = calculateWindowLevel()
        AppLogger.windows.info("Window level updated: \(window.level.rawValue)")
    }

    private func calculateWindowLevel() -> NSWindow.Level {
        if isEditModeEnabled && appSettings.enableEditModeAlignment {
            return .floating
        }
        return .statusBar + 1
    }

    private func synchronizeMissionControlBehavior(_ window: NSWindow) {
        let shouldManage = appSettings.managedByMissionControl
        AppLogger.windows.debug(
            "Updating window management: managedByMissionControl=\(shouldManage)")

        if shouldManage {
            window.collectionBehavior.insert(.managed)
        } else {
            window.collectionBehavior.remove(.managed)
        }
    }

    private func synchronizeAspectRatio(_ window: NSWindow) {
        let currentSize = window.frame.size
        let targetHeight = currentSize.width / aspectRatio

        let heightDifference = abs(currentSize.height - targetHeight)
        guard heightDifference > 1.0 else { return }

        let newSize = NSSize(width: currentSize.width, height: targetHeight)
        window.setContentSize(newSize)
        window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)

        AppLogger.windows.debug(
            """
            Window size updated: \(String(format: "%.1f", currentSize.width))x\
            \(String(format: "%.1f", targetHeight)) (ratio: \
            \(String(format: "%.2f", aspectRatio)))
            """
        )
    }
}
