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
    private let resizeThrottleInterval: TimeInterval = 0.1

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true // Ensure layer-backing

        DispatchQueue.main.async {
            guard let window = view.window else {
                logger.warning("Window reference unavailable during initialization")
                return
            }

            configureWindowDefaults(window)
            logger.info("Window initialized: \(Int(window.frame.width))x\(Int(window.frame.height))")
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Only proceed if view is still in window hierarchy
        guard nsView.window != nil, nsView.superview != nil else {
            return
        }

        // Ensure window updates happen on main thread
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            synchronizeEditModeState(window)
            synchronizeWindowConfiguration(window)
            
            // Throttle aspect ratio updates
            DispatchQueue.main.asyncAfter(deadline: .now() + resizeThrottleInterval) {
                guard nsView.window != nil, nsView.superview != nil else { return }
                synchronizeAspectRatio(window)
            }
        }
    }

    // MARK: - Window Configuration

    private func configureWindowDefaults(_ window: NSWindow) {
        window.backgroundColor = .clear
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.styleMask = NSWindow.StyleMask.fullSizeContentView
        
        // Add close button support
        window.styleMask.insert(.closable)
        window.standardWindowButton(.closeButton)?.isHidden = false

        logger.debug("Applied default window configuration")
    }

    private func synchronizeEditModeState(_ window: NSWindow) {
        var newStyleMask: NSWindow.StyleMask = .fullSizeContentView
        
        // Always keep closable enabled
        newStyleMask.insert(.closable)
        
        if previewManager.editModeEnabled {
            newStyleMask.insert(.resizable)
        }
        
        let newMovability: Bool = previewManager.editModeEnabled

        if window.styleMask != newStyleMask {
            window.styleMask = newStyleMask
            logger.debug("Window stylemask updated")
        }
        
        if window.isMovable != newMovability {
            window.isMovable = newMovability
            logger.debug("Window movability updated")
        }
    }

    private func synchronizeWindowConfiguration(_ window: NSWindow) {
        updateWindowLevel(window)
        updateMissionControlBehavior(window)
    }

    private func updateWindowLevel(_ window: NSWindow) {
        let shouldFloat = previewManager.editModeEnabled && appSettings.previewAlignmentEnabled
        let newLevel: NSWindow.Level = shouldFloat ? .floating : .statusBar + 1

        if window.level != newLevel {
            window.level = newLevel
            logger.debug("Window level updated: floating=\(shouldFloat)")
        }
    }

    private func updateMissionControlBehavior(_ window: NSWindow) {
        let shouldManage = appSettings.previewManagedByMissionControl

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

        let windowWidth = window.frame.width
        let windowHeight = window.frame.height
        let desiredHeight = windowWidth / aspectRatio

        let heightDifference = abs(windowHeight - desiredHeight)
        guard heightDifference > 1.0 else { return }

        let updatedSize = NSSize(width: windowWidth, height: desiredHeight)
        window.setContentSize(updatedSize)
        window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)

        logger.info("Window resized: \(Int(updatedSize.width))x\(Int(updatedSize.height))")
    }
}
