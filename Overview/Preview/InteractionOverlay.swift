/*
 Preview/InteractionOverlay.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages mouse events and window interaction states for Overview preview windows,
 providing seamless control over window focus and edit mode transitions.
*/

import SwiftUI

struct InteractionOverlay: NSViewRepresentable {
    @Binding var editModeEnabled: Bool
    @Binding var showingSelection: Bool

    let editModeAction: () -> Void
    let bringToFrontAction: () -> Void
    
    private let logger = AppLogger.interface

    func makeNSView(context: Context) -> NSView {
        let view = InputHandler()
        view.editModeEnabled = editModeEnabled
        view.showingSelection = showingSelection
        view.editModeAction = editModeAction
        view.bringToFrontAction = bringToFrontAction
        view.menu = createContextualMenu(for: view)

        logger.info("Interaction overlay view configured")
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? InputHandler else {
            logger.warning("Invalid view type in updateNSView")
            return
        }

        logger.debug(
            "Updating interaction overlay state: editMode=\(editModeEnabled)")
        view.editModeEnabled = editModeEnabled
        view.showingSelection = showingSelection
        view.editModeMenuItem?.state = editModeEnabled ? .on : .off
    }

    private func createContextualMenu(for view: InputHandler) -> NSMenu {
        logger.info("Creating context menu for interaction overlay")

        let menu = NSMenu()
        let editModeItem = NSMenuItem(
            title: "Edit Mode",
            action: #selector(InputHandler.toggleEditMode),
            keyEquivalent: ""
        )
        editModeItem.target = view
        menu.addItem(editModeItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Close Window",
                action: #selector(NSWindow.close),
                keyEquivalent: ""
            )
        )

        view.editModeMenuItem = editModeItem
        return menu
    }
}

private final class InputHandler: NSView {
    private let logger = AppLogger.interface
    var editModeEnabled = false
    var showingSelection = false
    var editModeAction: (() -> Void)?
    var bringToFrontAction: (() -> Void)?
    weak var editModeMenuItem: NSMenuItem?

    override func mouseDown(with event: NSEvent) {
        if !editModeEnabled && !showingSelection {
            logger.debug("Mouse down triggered window focus action")
            bringToFrontAction?()
        } else {
            logger.debug("Mouse down handled by system: editMode=\(editModeEnabled)")
            super.mouseDown(with: event)
        }
    }

    @objc func toggleEditMode() {
        logger.info("Edit mode toggled via context menu")
        editModeAction?()
    }
}
