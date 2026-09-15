/*
 Window/WindowAccessor.swift
 Overview

 Syncs edit-mode chrome and locks aspect once a source is assigned.
*/
import Defaults
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    @Binding var aspectRatio: CGFloat
    @ObservedObject var captureCoordinator: CaptureCoordinator
    @ObservedObject var previewManager: PreviewManager
    @ObservedObject var sourceManager: SourceManager

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window, nsView.superview != nil else { return }
        context.coordinator.sync(
            window: window,
            aspectRatio: aspectRatio,
            hasAssignment: captureCoordinator.hasAssignment,
            editModeEnabled: previewManager.editModeEnabled,
            isOverviewActive: sourceManager.isOverviewActive
        )
    }

    @MainActor
    final class Coordinator {
        private let configService = WindowServices.shared.windowConfiguration
        private let aspectService = WindowServices.shared.windowAspect
        private var lastEditMode: Bool?
        private var lastOverviewActive: Bool?
        private var lastAspectRatio: CGFloat = -1
        private var aspectLocked = false
        private var lastShadow: Bool?
        private var lastMissionControl: Bool?
        private var lastAllDesktops: Bool?

        func sync(
            window: NSWindow,
            aspectRatio: CGFloat,
            hasAssignment: Bool,
            editModeEnabled: Bool,
            isOverviewActive: Bool
        ) {
            // Skip level/size snaps while the user is dragging the window.
            let dragging = window.currentEvent?.type == .leftMouseDragged

            let editChanged = lastEditMode != editModeEnabled
            let overviewChanged = lastOverviewActive != isOverviewActive
            if !dragging, editChanged || overviewChanged {
                lastEditMode = editModeEnabled
                lastOverviewActive = isOverviewActive
                configService.updateResizability(window, isEditable: editModeEnabled)
                configService.updateMovability(window, isMovable: editModeEnabled)
                window.isMovableByWindowBackground = true
                let shouldFloat = editModeEnabled && isOverviewActive
                window.level = shouldFloat ? .floating : .statusBar + 1
            }

            let shadow = Defaults[.windowShadowEnabled]
            if lastShadow != shadow {
                lastShadow = shadow
                window.hasShadow = shadow
            }

            let mission = Defaults[.managedByMissionControl]
            if lastMissionControl != mission {
                lastMissionControl = mission
                configService.updateMissionControl(window, isManaged: mission)
            }

            let allDesktops = Defaults[.assignPreviewsToAllDesktops]
            if lastAllDesktops != allDesktops {
                lastAllDesktops = allDesktops
                configService.updateSpaceParticipation(window, joinsAllDesktops: allDesktops)
            }

            // Once a source is assigned, lock resize to that aspect; still allows drag + scale.
            let shouldLock =
                Defaults[.syncAspectRatio]
                && hasAssignment
                && aspectRatio > 0
                && aspectRatio.isFinite

            if shouldLock {
                let ratioChanged = abs(lastAspectRatio - aspectRatio) > 0.001
                let snap = (!aspectLocked || ratioChanged) && !dragging && !window.inLiveResize
                aspectService.applyAspectLock(
                    for: window,
                    aspectRatio: aspectRatio,
                    snapToRatio: snap
                )
                lastAspectRatio = aspectRatio
                aspectLocked = true
            } else if aspectLocked {
                aspectService.applyAspectLock(for: window, aspectRatio: nil, snapToRatio: false)
                lastAspectRatio = -1
                aspectLocked = false
            }
        }
    }
}
