/*
 InteractionView.swift
 Overview

 Created by William Pierce on 10/13/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

/// Provides user interaction controls for Overview preview windows
///
/// Key responsibilities:
/// - Handles mouse events for window focus control
/// - Manages context menu for edit mode and window controls
/// - Coordinates window interaction state with SwiftUI environment
///
/// Coordinates with:
/// - PreviewView: Parent view providing window state and actions
/// - CaptureManager: Handles window focus changes triggered by interactions
struct InteractionOverlay: NSViewRepresentable {
    @Binding var isEditModeEnabled: Bool
    let isBringToFrontEnabled: Bool
    let bringToFrontAction: () -> Void
    let toggleEditModeAction: () -> Void

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSView {
        let view = InteractionView()
        view.isEditModeEnabled = isEditModeEnabled
        view.isBringToFrontEnabled = isBringToFrontEnabled
        view.bringToFrontAction = bringToFrontAction
        view.toggleEditModeAction = toggleEditModeAction
        view.menu = createContextMenu(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? InteractionView else { return }
        view.isEditModeEnabled = isEditModeEnabled
        view.editModeMenuItem?.state = isEditModeEnabled ? .on : .off
    }

    /// Creates the context menu with edit mode toggle and window controls
    private func createContextMenu(for view: InteractionView) -> NSMenu {
        let menu = NSMenu()

        let editModeItem = NSMenuItem(
            title: "Edit Mode",
            action: #selector(InteractionView.toggleEditMode),
            keyEquivalent: ""
        )
        editModeItem.target = view
        menu.addItem(editModeItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(title: "Close Window", action: #selector(NSWindow.close), keyEquivalent: ""))

        view.editModeMenuItem = editModeItem
        return menu
    }
}

/// Context: Handles low-level mouse events and menu interactions, coordinating with
/// InteractionOverlay for state management
private final class InteractionView: NSView {
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
