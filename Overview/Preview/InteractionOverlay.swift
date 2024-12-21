/*
 Preview/InteractionOverlay.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages mouse events and window interaction states for Overview preview windows,
 providing seamless control over window focus and edit mode transitions.
*/

import SwiftUI

struct InteractionOverlay: NSViewRepresentable {
    @Binding var editMode: Bool

    private let logger = AppLogger.interface
    let bringToFront: Bool
    let bringToFrontAction: () -> Void
    let toggleEditModeAction: () -> Void

    func makeNSView(context: Context) -> NSView {

        let view = InputHandler()
        view.editMode = editMode
        view.bringToFront = bringToFront
        view.bringToFrontAction = bringToFrontAction
        view.toggleEditModeAction = toggleEditModeAction
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
            "Updating interaction overlay state: editMode=\(editMode)")
        view.editMode = editMode
        view.editModeMenuItem?.state = editMode ? .on : .off
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
    var editMode = false
    var bringToFront = false
    var bringToFrontAction: (() -> Void)?
    var toggleEditModeAction: (() -> Void)?
    weak var editModeMenuItem: NSMenuItem?

    override func mouseDown(with event: NSEvent) {
        if !editMode && bringToFront {
            logger.debug("Mouse down triggered window focus action")
            bringToFrontAction?()
        } else {
            logger.debug("Mouse down handled by system: editMode=\(editMode)")
            super.mouseDown(with: event)
        }
    }

    @objc func toggleEditMode() {
        logger.info("Edit mode toggled via context menu")
        toggleEditModeAction?()
    }
}
