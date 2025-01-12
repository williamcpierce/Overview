/*
 Preview/PreviewInteractionOverlay.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages user interaction with preview windows, including context menus
 and edit mode toggling functionality.
*/

import SwiftUI

struct PreviewInteractionOverlay: NSViewRepresentable {
    @Binding var editModeEnabled: Bool
    @Binding var isSelectionViewVisible: Bool
    @Environment(\.dismiss) private var dismiss
    let onEditModeToggle: () -> Void
    let onSourceWindowFocus: () -> Void
    private let logger = AppLogger.interface

    func makeNSView(context: Context) -> NSView {
        let handler = PreviewInteractionHandler()
        configureHandler(handler)
        logger.debug("Created interaction handler view")
        return handler
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let handler = nsView as? PreviewInteractionHandler else {
            logger.warning("Invalid handler type during update")
            return
        }

        updateHandlerState(handler)
    }

    // MARK: - Configuration

    private func configureHandler(_ handler: PreviewInteractionHandler) {
        handler.editModeEnabled = editModeEnabled
        handler.isSelectionViewVisible = isSelectionViewVisible
        handler.onEditModeToggle = onEditModeToggle
        handler.onSourceWindowFocus = onSourceWindowFocus
        handler.onCloseWindow = {
            dismiss()
        }
        handler.menu = createContextMenu(for: handler)

        logger.debug("Handler configured with initial state")
    }

    private func updateHandlerState(_ handler: PreviewInteractionHandler) {
        let previousEditMode = handler.editModeEnabled
        handler.editModeEnabled = editModeEnabled
        handler.isSelectionViewVisible = isSelectionViewVisible
        handler.editModeMenuItem?.state = editModeEnabled ? .on : .off

        if previousEditMode != editModeEnabled {
            logger.debug("Edit mode state updated: \(editModeEnabled)")
        }
    }

    private func createContextMenu(for handler: PreviewInteractionHandler) -> NSMenu {
        let menu = NSMenu()
        let editModeItem = createEditModeMenuItem(for: handler)

        menu.addItem(editModeItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(createCloseWindowMenuItem(for: handler))

        handler.editModeMenuItem = editModeItem
        return menu
    }

    private func createEditModeMenuItem(for handler: PreviewInteractionHandler) -> NSMenuItem {
        let item = NSMenuItem(
            title: "Edit Mode",
            action: #selector(PreviewInteractionHandler.toggleEditMode),
            keyEquivalent: ""
        )
        item.target = handler
        return item
    }

    private func createCloseWindowMenuItem(for handler: PreviewInteractionHandler) -> NSMenuItem {
        let item = NSMenuItem(
            title: "Close Window",
            action: #selector(PreviewInteractionHandler.closeWindow),
            keyEquivalent: ""
        )
        item.target = handler
        return item
    }
}

private final class PreviewInteractionHandler: NSView {
    private let logger = AppLogger.interface
    var editModeEnabled: Bool = false
    var isSelectionViewVisible: Bool = false
    var onEditModeToggle: (() -> Void)?
    var onSourceWindowFocus: (() -> Void)?
    var onCloseWindow: (() -> Void)?
    weak var editModeMenuItem: NSMenuItem?

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

    @objc func closeWindow() {
        logger.info("Window close requested via context menu")
        onCloseWindow?()
    }
}
