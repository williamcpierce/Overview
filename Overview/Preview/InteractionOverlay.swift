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
    @Binding var isSelectionViewVisible: Bool
    
    let onEditModeToggle: () -> Void
    let onSourceWindowFocus: () -> Void
    
    private let logger = AppLogger.interface
    
    func makeNSView(context: Context) -> NSView {
        let handler = WindowInteractionHandler()
        configureHandler(handler)
        return handler
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let handler = nsView as? WindowInteractionHandler else {
            logger.warning("Invalid handler type in updateNSView")
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
        handler.menu = createContextMenu(for: handler)
        
        logger.info("Handler configured")
    }
    
    private func updateHandlerState(_ handler: WindowInteractionHandler) {
        handler.editModeEnabled = editModeEnabled
        handler.isSelectionViewVisible = isSelectionViewVisible
        handler.editModeMenuItem?.state = editModeEnabled ? .on : .off
    }
    
    private func createContextMenu(for handler: WindowInteractionHandler) -> NSMenu {
        let menu = NSMenu()
        
        let editModeItem = createEditModeMenuItem(for: handler)
        menu.addItem(editModeItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(createCloseWindowMenuItem())
        
        handler.editModeMenuItem = editModeItem
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
    
    private func createCloseWindowMenuItem() -> NSMenuItem {
        NSMenuItem(
            title: "Close Window",
            action: #selector(NSWindow.close),
            keyEquivalent: ""
        )
    }
}

private final class WindowInteractionHandler: NSView {
    var editModeEnabled = false
    var isSelectionViewVisible = false
    
    var onEditModeToggle: (() -> Void)?
    var onSourceWindowFocus: (() -> Void)?
    
    weak var editModeMenuItem: NSMenuItem?
    
    private let logger = AppLogger.interface
    
    // MARK: - Mouse Events
    
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
        logger.debug("Focusing source window")
        onSourceWindowFocus?()
    }
    
    private func handleSystemMouseEvent(_ event: NSEvent) {
        logger.debug("Delegating mouse event to system")
        super.mouseDown(with: event)
    }
    
    // MARK: - Menu Actions
    
    @objc func toggleEditMode() {
        logger.info("Edit mode toggled via menu")
        onEditModeToggle?()
    }
}
