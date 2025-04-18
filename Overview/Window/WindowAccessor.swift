/*
 Window/WindowAccessor.swift
 Overview

 Created by William Pierce on 1/12/25.

 Manages window state synchronization through SwiftUI's NSViewRepresentable interface.
*/

import Defaults
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    // Constants
    private struct Constants {
        static let throttleInterval: TimeInterval = 0.1
    }

    // Dependencies
    @Binding var aspectRatio: CGFloat
    @ObservedObject var captureCoordinator: CaptureCoordinator
    @ObservedObject var previewManager: PreviewManager
    @ObservedObject var sourceManager: SourceManager
    private let configService = WindowServices.shared.windowConfiguration
    private let aspectService = WindowServices.shared.windowAspect
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

    private func synchronizeEditableState(_ window: NSWindow) {
        configService.updateResizability(window, isEditable: previewManager.editModeEnabled)
        configService.updateMovability(window, isMovable: previewManager.editModeEnabled)
    }

    private func synchronizeLayoutAndBehavior(_ window: NSWindow) {
        let shouldFloat = previewManager.editModeEnabled && sourceManager.isOverviewActive
        let newLevel: NSWindow.Level = shouldFloat ? .floating : .statusBar + 1

        window.level = newLevel
        window.hasShadow = Defaults[.windowShadowEnabled]

        if Defaults[.syncAspectRatio] {
            aspectService.synchronizeAspectRatio(
                for: window,
                aspectRatio: aspectRatio,
                isCapturing: captureCoordinator.isCapturing
            )
        }

        configService.updateMissionControl(window, isManaged: Defaults[.managedByMissionControl])

        var currentBehavior = window.collectionBehavior
        if Defaults[.assignPreviewsToAllDesktops] {
            currentBehavior.insert(.canJoinAllSpaces)
        } else {
            currentBehavior.remove(.canJoinAllSpaces)
        }
        window.collectionBehavior = currentBehavior
    }
}
