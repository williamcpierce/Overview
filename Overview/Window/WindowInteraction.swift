/*
 Window/WindowInteraction.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages user interaction with preview windows, including context menus
 and edit mode toggling functionality.
*/

import SwiftUI

struct WindowInteraction: NSViewRepresentable {
    // Dependencies
    private let logger = AppLogger.interface

    // Bindings
    @Binding var editModeEnabled: Bool
    @Binding var isSelectionViewVisible: Bool

    // Actions
    let onEditModeToggle: () -> Void
    let onSourceWindowFocus: () -> Void
    let teardownCapture: () async -> Void
    let onClose: () -> Void

    func makeNSView(context: Context) -> NSView {
        let handler = WindowInteractionHandler()
        handler.onEditModeToggle = onEditModeToggle
        handler.onSourceWindowFocus = onSourceWindowFocus
        handler.onStopCapture = { Task { @MainActor in await teardownCapture() }}
        handler.onCloseWindow = { Task { @MainActor in await teardownCapture(); onClose() }}
        handler.updateState(editModeEnabled: editModeEnabled, isSelectionVisible: isSelectionViewVisible)
        return handler
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let handler = nsView as? WindowInteractionHandler else { return }
        handler.updateState(editModeEnabled: editModeEnabled, isSelectionVisible: isSelectionViewVisible)
    }
}

private final class WindowInteractionHandler: NSView, NSMenuDelegate {
    // Dependencies
    private let logger = AppLogger.interface

    // Menu Items
    private let editModeItem: NSMenuItem
    private let stopCaptureItem: NSMenuItem
    private let contextMenu: NSMenu

    // State
    private var editModeEnabled = false
    private var isSelectionVisible = false

    // Actions
    var onEditModeToggle: (() -> Void)?
    var onSourceWindowFocus: (() -> Void)?
    var onStopCapture: (() -> Void)?
    var onCloseWindow: (() -> Void)?

    override init(frame: NSRect) {
        editModeItem = NSMenuItem(title: "Edit Mode", action: #selector(toggleEditMode), keyEquivalent: "")
        stopCaptureItem = NSMenuItem(title: "Stop Capture", action: #selector(stopCapture), keyEquivalent: "")
        let closeItem = NSMenuItem(title: "Close Window", action: #selector(closeWindow), keyEquivalent: "")

        contextMenu = NSMenu()
        contextMenu.autoenablesItems = false

        super.init(frame: frame)

        editModeItem.target = self
        stopCaptureItem.target = self
        closeItem.target = self

        contextMenu.addItem(editModeItem)
        contextMenu.addItem(stopCaptureItem)
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(closeItem)
        
        contextMenu.delegate = self
        menu = contextMenu
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func updateState(editModeEnabled: Bool, isSelectionVisible: Bool) {
        self.editModeEnabled = editModeEnabled
        self.isSelectionVisible = isSelectionVisible
        
        editModeItem.state = editModeEnabled ? .on : .off
        stopCaptureItem.isEnabled = !isSelectionVisible
    }

    override func mouseDown(with event: NSEvent) {
        if !editModeEnabled && !isSelectionVisible {
            onSourceWindowFocus?()
        } else {
            super.mouseDown(with: event)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        stopCaptureItem.isEnabled = !isSelectionVisible
    }

    @objc private func toggleEditMode() { onEditModeToggle?() }
    @objc private func stopCapture() { onStopCapture?() }
    @objc private func closeWindow() { onCloseWindow?() }
}
