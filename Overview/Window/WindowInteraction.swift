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
    @Binding var editModeEnabled: Bool
    @Binding var isSelectionViewVisible: Bool
    private let logger = AppLogger.interface

    // Actions
    let onEditModeToggle: () -> Void
    let onSourceWindowFocus: () -> Void
    let teardownCapture: () async -> Void
    let onClose: () -> Void

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSView {
        let handler = WindowInteractionHandler()
        configureHandler(handler)
        logger.debug("Created interaction handler view")
        return handler
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let handler = nsView as? WindowInteractionHandler else {
            logger.warning("Invalid handler type during update")
            return
        }

        logger.debug(
            "Updating state - selectionVisible=\(isSelectionViewVisible), editMode=\(editModeEnabled)"
        )
        handler.updateState(
            editModeEnabled: editModeEnabled,
            isSelectionViewVisible: isSelectionViewVisible
        )
    }

    private func configureHandler(_ handler: WindowInteractionHandler) {
        handler.onEditModeToggle = onEditModeToggle
        handler.onSourceWindowFocus = onSourceWindowFocus
        handler.onCloseWindow = {
            Task { @MainActor in
                await teardownCapture()
                onClose()
            }
        }
        handler.onStopCapture = {
            Task { @MainActor in
                await teardownCapture()
            }
        }

        handler.updateState(
            editModeEnabled: editModeEnabled,
            isSelectionViewVisible: isSelectionViewVisible
        )
    }
}

private final class WindowInteractionHandler: NSView, NSMenuDelegate {
    // Dependencies
    private let logger = AppLogger.interface

    // Private State
    private var editModeEnabled: Bool = false
    private var isSelectionViewVisible: Bool = false

    // Menu Items
    private let contextMenu: NSMenu
    private let editModeItem: NSMenuItem
    private let stopCaptureItem: NSMenuItem

    // Actions
    var onEditModeToggle: (() -> Void)?
    var onSourceWindowFocus: (() -> Void)?
    var onCloseWindow: (() -> Void)?
    var onStopCapture: (() -> Void)?

    override init(frame frameRect: NSRect) {
        editModeItem = NSMenuItem(
            title: "Edit Mode", action: #selector(toggleEditMode), keyEquivalent: "")
        stopCaptureItem = NSMenuItem(
            title: "Stop Capture", action: #selector(stopCapture), keyEquivalent: "")
        let closeItem = NSMenuItem(
            title: "Close Window", action: #selector(closeWindow), keyEquivalent: "")

        contextMenu = NSMenu()
        contextMenu.autoenablesItems = false

        super.init(frame: frameRect)

        editModeItem.target = self
        stopCaptureItem.target = self
        closeItem.target = self

        contextMenu.addItem(editModeItem)
        contextMenu.addItem(stopCaptureItem)
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(closeItem)

        contextMenu.delegate = self
        menu = contextMenu

        logger.debug("Handler initialized with menu")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - State Management

    func updateState(editModeEnabled: Bool, isSelectionViewVisible: Bool) {
        let previousSelectionVisible = self.isSelectionViewVisible
        let previousStopEnabled = stopCaptureItem.isEnabled

        self.editModeEnabled = editModeEnabled
        self.isSelectionViewVisible = isSelectionViewVisible

        updateMenuState()

        let currentStopEnabled = stopCaptureItem.isEnabled
    }

    private func updateMenuState() {
        editModeItem.state = editModeEnabled ? .on : .off

        if isSelectionViewVisible && stopCaptureItem.isEnabled {
            stopCaptureItem.isEnabled = false
            logger.debug("Forcing stop capture disable due to selection visible")
        } else if !isSelectionViewVisible && !stopCaptureItem.isEnabled {
            stopCaptureItem.isEnabled = true
            logger.debug("Enabling stop capture due to selection hidden")
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuState()
        logger.debug(
            "Menu will open - enforcing state: stopCapture.enabled=\(stopCaptureItem.isEnabled)")
    }

    // MARK: - Event Handling

    override func mouseDown(with event: NSEvent) {
        if !editModeEnabled && !isSelectionViewVisible {
            onSourceWindowFocus?()
            logger.debug("Processing mouse click for source window focus")
        } else {
            super.mouseDown(with: event)
            logger.debug("Delegating mouse event to system handler")
        }
    }

    // MARK: - Menu Actions

    @objc private func toggleEditMode() {
        logger.info("Edit mode toggled via context menu")
        onEditModeToggle?()
    }

    @objc private func stopCapture() {
        logger.info("Stop capture requested via context menu")
        onStopCapture?()
    }

    @objc private func closeWindow() {
        logger.info("Window close requested via context menu")
        onCloseWindow?()
    }
}
