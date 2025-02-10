/*
 Window/WindowInteraction.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages user interaction with preview windows, including context menus
 and edit mode toggling functionality.
*/

import SwiftUI

struct WindowInteraction: NSViewRepresentable {
    // Dependencies
    @Binding var editModeEnabled: Bool
    @Binding var isSelectionViewVisible: Bool
    private let logger = AppLogger.interface

    // Actions
    let onEditModeToggle: () -> Void
    let onSourceWindowFocus: () -> Void
    let teardownCapture: () async -> Void
    let onClose: () -> Void

    func makeNSView(context: Context) -> NSView {
        let handler = WindowInteractionHandler()
        configureHandler(handler)
        logger.debug("Created interaction handler view")
        return handler
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let handler = nsView as? WindowInteractionHandler else {
            logger.warning("Invalid handler type during update")
            return
        }

        updateHandlerState(handler)
    }

    // MARK: - Configuration

    private func configureHandler(_ handler: WindowInteractionHandler) {
        handler.editModeEnabled = editModeEnabled
        handler.isSelectionViewVisible = isSelectionViewVisible
        handler.onEditModeToggle = onEditModeToggle
        handler.onSourceWindowFocus = onSourceWindowFocus
        handler.onCloseWindow = {
            Task { @MainActor in
                await teardownCapture()
                onClose()
            }
        }
        handler.onStopCapture = {
            Task { @MainActor in
                await teardownCapture()
            }
        }
        handler.menu = createContextMenu(for: handler)
        logger.debug("Handler configured with initial state")
    }

    private func updateHandlerState(_ handler: WindowInteractionHandler) {
        let previousEditMode: Bool = handler.editModeEnabled
        handler.editModeEnabled = editModeEnabled
        handler.isSelectionViewVisible = isSelectionViewVisible
        handler.editModeMenuItem?.state = editModeEnabled ? .on : .off
        handler.stopCaptureMenuItem?.isEnabled = !isSelectionViewVisible

        if previousEditMode != editModeEnabled {
            logger.debug("Edit mode state updated: \(editModeEnabled)")
        }
    }

    private func createContextMenu(for handler: WindowInteractionHandler) -> NSMenu {
        let menu = NSMenu()
        let editModeItem: NSMenuItem = createEditModeMenuItem(for: handler)
        let stopCaptureItem: NSMenuItem = createStopCaptureMenuItem(for: handler)

        menu.addItem(editModeItem)
        menu.addItem(stopCaptureItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(createCloseWindowMenuItem(for: handler))

        handler.editModeMenuItem = editModeItem
        handler.stopCaptureMenuItem = stopCaptureItem
        return menu
    }

    private func createEditModeMenuItem(for handler: WindowInteractionHandler) -> NSMenuItem {
        let item = NSMenuItem(
            title: "Edit Mode",
            action: #selector(WindowInteractionHandler.toggleEditMode),
            keyEquivalent: ""
        )
        item.target = handler
        return item
    }

    private func createStopCaptureMenuItem(for handler: WindowInteractionHandler) -> NSMenuItem {
        let item = NSMenuItem(
            title: "Stop Capture",
            action: #selector(WindowInteractionHandler.stopCapture),
            keyEquivalent: ""
        )
        item.target = handler
        return item
    }

    private func createCloseWindowMenuItem(for handler: WindowInteractionHandler) -> NSMenuItem {
        let item = NSMenuItem(
            title: "Close Window",
            action: #selector(WindowInteractionHandler.closeWindow),
            keyEquivalent: ""
        )
        item.target = handler
        return item
    }
}

// MARK: - Interaction Handler

private final class WindowInteractionHandler: NSView {
    // Dependencies
    private let logger = AppLogger.interface

    // Private State
    var editModeEnabled: Bool = false
    var isSelectionViewVisible: Bool = false
    weak var editModeMenuItem: NSMenuItem?
    weak var stopCaptureMenuItem: NSMenuItem?

    // Actions
    var onEditModeToggle: (() -> Void)?
    var onSourceWindowFocus: (() -> Void)?
    var onCloseWindow: (() -> Void)?
    var onStopCapture: (() -> Void)?

    // MARK: - Mouse Event Handling

    override func mouseDown(with event: NSEvent) {
        if shouldHandleMouseClick {
            handleMouseClick()
        } else {
            handleSystemMouseEvent(event)
        }
    }

    private var shouldHandleMouseClick: Bool {
        !editModeEnabled && !isSelectionViewVisible
    }

    private func handleMouseClick() {
        logger.debug("Processing mouse click for source window focus")
        onSourceWindowFocus?()
    }

    private func handleSystemMouseEvent(_ event: NSEvent) {
        logger.debug("Delegating mouse event to system handler")
        super.mouseDown(with: event)
    }

    // MARK: - Menu Actions

    @objc func toggleEditMode() {
        logger.info("Edit mode toggled via context menu")
        onEditModeToggle?()
    }

    @objc func stopCapture() {
        logger.info("Stop capture requested via context menu")
        onStopCapture?()
    }

    @objc func closeWindow() {
        logger.info("Window close requested via context menu")
        onCloseWindow?()
    }
}
