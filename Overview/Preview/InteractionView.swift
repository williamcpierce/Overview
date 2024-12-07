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

struct InteractionOverlay: NSViewRepresentable {
    // MARK: - Properties
    @Binding var isEditModeEnabled: Bool
    let isBringToFrontEnabled: Bool
    let bringToFrontAction: () -> Void
    let toggleEditModeAction: () -> Void
    
    // MARK: - NSViewRepresentable Methods
    func makeNSView(context: Context) -> NSView {
        let view = InteractionView()
        configureView(view)
        view.menu = createContextMenu(for: view)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? InteractionView else { return }
        view.isEditModeEnabled = isEditModeEnabled
        view.updateEditModeMenuItem()
    }
    
    // MARK: - Private Methods
    private func configureView(_ view: InteractionView) {
        view.isEditModeEnabled = isEditModeEnabled
        view.isBringToFrontEnabled = isBringToFrontEnabled
        view.bringToFrontAction = bringToFrontAction
        view.toggleEditModeAction = toggleEditModeAction
    }
    
    private func createContextMenu(for view: InteractionView) -> NSMenu {
        let menu = NSMenu()
        
        // Add Edit Mode item
        let editModeItem = NSMenuItem(
            title: "Edit Mode",
            action: #selector(InteractionView.toggleEditMode(_:)),
            keyEquivalent: ""
        )
        editModeItem.target = view
        menu.addItem(editModeItem)
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add Close Window item
        let closeItem = NSMenuItem(
            title: "Close Window",
            action: #selector(NSWindow.close),
            keyEquivalent: ""
        )
        menu.addItem(closeItem)
        
        view.editModeMenuItem = editModeItem
        return menu
    }
}

// MARK: - InteractionView Implementation
extension InteractionOverlay {
    final class InteractionView: NSView {
        // MARK: - Properties
        var isEditModeEnabled = false {
            didSet { updateEditModeMenuItem() }
        }
        var isBringToFrontEnabled: Bool = false
        var bringToFrontAction: (() -> Void)?
        var toggleEditModeAction: (() -> Void)?
        weak var editModeMenuItem: NSMenuItem?
        
        // MARK: - Mouse Event Handling
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
        
        // MARK: - Actions
        @objc func toggleEditMode(_ sender: Any?) {
            toggleEditModeAction?()
        }
        
        func updateEditModeMenuItem() {
            editModeMenuItem?.state = isEditModeEnabled ? .on : .off
        }
    }
}
