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
    var isBringToFrontEnabled: Bool
    var bringToFrontAction: () -> Void
    var toggleEditModeAction: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = InteractionView()
        view.isEditModeEnabled = isEditModeEnabled
        view.isBringToFrontEnabled = isBringToFrontEnabled
        view.bringToFrontAction = bringToFrontAction
        view.toggleEditModeAction = toggleEditModeAction

        let menu = createContextMenu(for: view)
        view.menu = menu

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? InteractionView {
            view.isEditModeEnabled = isEditModeEnabled
            view.updateEditModeMenuItem()
        }
    }

    private func createContextMenu(for view: InteractionView) -> NSMenu {
        let menu = NSMenu()

        let editModeItem = NSMenuItem(
            title: "Edit Mode", action: #selector(InteractionView.toggleEditMode(_:)),
            keyEquivalent: "")
        editModeItem.target = view
        menu.addItem(editModeItem)

        menu.addItem(NSMenuItem.separator())

        let closeItem = NSMenuItem(
            title: "Close Window", action: #selector(NSWindow.close), keyEquivalent: "")
        closeItem.target = nil
        menu.addItem(closeItem)

        view.editModeMenuItem = editModeItem

        return menu
    }

    class InteractionView: NSView {
        var isEditModeEnabled = false {
            didSet { updateEditModeMenuItem() }
        }
        var isBringToFrontEnabled: Bool = false
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

        override func rightMouseDown(with event: NSEvent) {
            super.rightMouseDown(with: event)
        }

        @objc func toggleEditMode(_ sender: Any?) {
            toggleEditModeAction?()
        }

        func updateEditModeMenuItem() {
            editModeMenuItem?.state = isEditModeEnabled ? .on : .off
        }
    }
}
