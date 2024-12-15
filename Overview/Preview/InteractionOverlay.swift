/*
 InteractionOverlay.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages mouse events and window interaction states for Overview preview windows,
 providing seamless control over window focus and edit mode transitions.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

/// Manages user interactions and window state transitions for preview windows
///
/// Key responsibilities:
/// - Processes mouse events for window focus activation
/// - Manages edit mode toggling through context menu
/// - Coordinates window interaction states with parent views
/// - Maintains interaction consistency across edit mode states
///
/// Coordinates with:
/// - PreviewView: Provides window state and callback actions
/// - CaptureManager: Handles window focus state changes
/// - PreviewAccessor: Controls preview window level during edit mode
/// - AppSettings: Applies window interaction preferences
struct InteractionOverlay: NSViewRepresentable {
    // MARK: - Properties

    /// Controls window editing capabilities (move/resize)
    /// - Note: Bound to global edit mode state in PreviewManager
    @Binding var isEditModeEnabled: Bool

    /// Controls whether clicking activates source window focus
    /// - Note: Disabled during edit mode to prevent accidental switching
    let isBringToFrontEnabled: Bool

    /// Activates the source window on click
    /// - Note: Only triggered when edit mode is disabled
    let bringToFrontAction: () -> Void

    /// Toggles edit mode state
    /// - Note: Propagates through PreviewManager to all windows
    let toggleEditModeAction: () -> Void

    // MARK: - NSViewRepresentable Implementation

    /// Creates and configures the interaction overlay with initial state
    ///
    /// Flow:
    /// 1. Creates base interaction overlay instance
    /// 2. Configures window interaction properties
    /// 3. Sets up context menu with edit mode toggle
    ///
    /// - Parameter context: View creation context
    /// - Returns: Configured NSView for window interactions
    func makeNSView(context: Context) -> NSView {
        AppLogger.interface.debug("Creating interaction overlay view")
        
        let view = ClickHandler()
        view.isEditModeEnabled = isEditModeEnabled
        view.isBringToFrontEnabled = isBringToFrontEnabled
        view.bringToFrontAction = bringToFrontAction
        view.toggleEditModeAction = toggleEditModeAction
        view.menu = createContextMenu(for: view)
        
        AppLogger.interface.info("Interaction overlay view configured")
        return view
    }

    /// Updates interaction overlay state when bindings change
    ///
    /// Flow:
    /// 1. Validates view type
    /// 2. Updates edit mode state
    /// 3. Synchronizes menu item state
    ///
    /// - Parameters:
    ///   - nsView: View to update
    ///   - context: Update context
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? ClickHandler else {
            AppLogger.interface.warning("Invalid view type in updateNSView")
            return
        }
        
        AppLogger.interface.debug("Updating interaction overlay state: editMode=\(isEditModeEnabled)")
        view.isEditModeEnabled = isEditModeEnabled
        view.editModeMenuItem?.state = isEditModeEnabled ? .on : .off
    }

    // MARK: - Private Methods

    /// Creates the window control context menu
    ///
    /// Context: Using NSMenu instead of SwiftUI menu for proper window level
    /// handling during edit mode transitions. SwiftUI menus can interfere
    /// with window level changes.
    ///
    /// Flow:
    /// 1. Creates base menu instance
    /// 2. Adds edit mode toggle item
    /// 3. Adds window management items
    /// 4. Stores reference for state updates
    ///
    /// - Parameter view: Target interaction view
    /// - Returns: Configured NSMenu instance
    private func createContextMenu(for view: ClickHandler) -> NSMenu {
        AppLogger.interface.debug("Creating context menu for interaction overlay")
        
        let menu = NSMenu()

        // Context: Empty key equivalent prevents menu shortcut conflicts
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

/// Handles low-level mouse events and menu interactions
///
/// Key responsibilities:
/// - Processes mouse events for window focus control
/// - Manages context menu state updates
/// - Coordinates with parent overlay for state changes
///
/// Context: Uses NSView directly to bypass SwiftUI event handling,
/// ensuring consistent behavior across window states and levels
private final class ClickHandler: NSView {
    // MARK: - Properties

    /// Controls whether window can be moved and resized
    /// - Note: Affects mouse event handling behavior
    var isEditModeEnabled = false

    /// Whether clicking should focus source window
    /// - Note: Disabled during edit mode
    var isBringToFrontEnabled = false

    /// Action to focus source window
    /// - Note: Called on mouse down when appropriate
    var bringToFrontAction: (() -> Void)?

    /// Action to toggle edit mode state
    /// - Note: Called by menu item selection
    var toggleEditModeAction: (() -> Void)?

    /// Reference to edit mode menu item for state updates
    /// - Note: Weak reference to prevent retention cycle with menu
    weak var editModeMenuItem: NSMenuItem?

    // MARK: - Event Handling

    /// Processes mouse down events based on current state
    ///
    /// Flow:
    /// 1. Checks edit mode and bring-to-front state
    /// 2. Triggers focus action if appropriate
    /// 3. Falls back to default handling
    ///
    /// - Parameter event: Mouse event to process
    override func mouseDown(with event: NSEvent) {
        if !isEditModeEnabled && isBringToFrontEnabled {
            AppLogger.interface.debug("Mouse down triggered window focus action")
            bringToFrontAction?()
        } else {
            AppLogger.interface.debug("Mouse down handled by system: editMode=\(isEditModeEnabled)")
            super.mouseDown(with: event)
        }
    }

    /// Toggles edit mode state via menu action
    ///
    /// Context: Called by menu item, propagates change through
    /// parent overlay to maintain consistent window state
    @objc func toggleEditMode() {
        AppLogger.interface.info("Edit mode toggled via context menu")
        toggleEditModeAction?()
    }
}
