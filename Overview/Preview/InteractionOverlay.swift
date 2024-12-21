/*
 Preview/InteractionOverlay.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages mouse events and window interaction states for Overview preview windows,
 providing seamless control over window focus and edit mode transitions.
*/

import SwiftUI

struct InteractionOverlay: NSViewRepresentable {
    @Binding var isEditModeEnabled: Bool
    private let logger = AppLogger.interface
    let bringToFrontAction: () -> Void
    let toggleEditModeAction: () -> Void

    func makeNSView(context: Context) -> NSView {
        AppLogger.interface.debug("Creating interaction overlay view")

        let view = InputHandler()
        view.isEditModeEnabled = isEditModeEnabled
        view.isBringToFrontEnabled = isBringToFrontEnabled
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

        logger.info(
            "Updating interaction overlay state: editMode=\(editMode)")
        view.isEditModeEnabled = isEditModeEnabled
        view.editModeMenuItem?.state = isEditModeEnabled ? .on : .off
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
    var isEditModeEnabled = false
    var isBringToFrontEnabled = false
    var bringToFrontAction: (() -> Void)?
    var toggleEditModeAction: (() -> Void)?
    weak var editModeMenuItem: NSMenuItem?

    override func mouseDown(with event: NSEvent) {
        if !isEditModeEnabled && isBringToFrontEnabled {
            logger.info("Mouse down triggered window focus action")
            bringToFrontAction?()
        } else {
            logger.info("Mouse down handled by system: editMode=\(editMode)")
            super.mouseDown(with: event)
        }
    }

    @objc func toggleEditMode() {
        logger.info("Edit mode toggled via context menu")
        toggleEditModeAction?()
    }
}
