/*
 InteractionOverlay.swift
 Overview

 Created by William Pierce on 10/13/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

struct InteractionOverlay: NSViewRepresentable {
    @Binding var isEditModeEnabled: Bool

    let isBringToFrontEnabled: Bool
    let bringToFrontAction: () -> Void
    let toggleEditModeAction: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ClickHandler()
        view.isEditModeEnabled = isEditModeEnabled
        view.isBringToFrontEnabled = isBringToFrontEnabled
        view.bringToFrontAction = bringToFrontAction
        view.toggleEditModeAction = toggleEditModeAction
        view.menu = createContextMenu(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? ClickHandler else { return }
        view.isEditModeEnabled = isEditModeEnabled
        view.editModeMenuItem?.state = isEditModeEnabled ? .on : .off
    }

    private func createContextMenu(for view: ClickHandler) -> NSMenu {
        let menu = NSMenu()

        let editModeItem = NSMenuItem(
            title: "Edit Mode",
            action: #selector(ClickHandler.toggleEditMode),
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

private final class ClickHandler: NSView {
    var isEditModeEnabled = false
    var isBringToFrontEnabled = false
    var bringToFrontAction: (() -> Void)?
    var toggleEditModeAction: (() -> Void)?
    weak var editModeMenuItem: NSMenuItem?

    override func mouseDown(with event: NSEvent) {
        if !isEditModeEnabled && isBringToFrontEnabled {
            bringToFrontAction?()
        } else {
            super.mouseDown(with: event)
        }
    }

    @objc func toggleEditMode() {
        toggleEditModeAction?()
    }
}
