/*
 Window/WindowInteraction.swift
 Overview

 Preview clicks, context menu, and edit-mode window dragging.
*/
import AppKit
import SwiftUI

struct WindowInteraction: NSViewRepresentable {
    @Binding var editModeEnabled: Bool
    @Binding var isSelectionViewVisible: Bool
    var hideWhenFocused: Bool
    /// When true, Hide When Focused is forced on (multi-source groups).
    var hideWhenFocusedLocked: Bool = false
    let onEditModeToggle: () -> Void
    let onSourceWindowFocus: () -> Void
    let onManageSourceGroup: () -> Void
    let onToggleHideWhenFocused: () -> Void
    let teardownCapture: () async -> Void
    let onClose: () -> Void

    func makeNSView(context: Context) -> NSView {
        let handler = WindowInteractionHandler()
        apply(handler)
        return handler
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let handler = nsView as? WindowInteractionHandler else { return }
        apply(handler)
    }

    private func apply(_ handler: WindowInteractionHandler) {
        handler.onEditModeToggle = onEditModeToggle
        handler.onSourceWindowFocus = onSourceWindowFocus
        handler.onManageSourceGroup = onManageSourceGroup
        handler.onToggleHideWhenFocused = onToggleHideWhenFocused
        handler.onStopCapture = { Task { @MainActor in await teardownCapture() } }
        handler.onCloseWindow = {
            Task { @MainActor in
                await teardownCapture()
                onClose()
            }
        }
        handler.updateState(
            editModeEnabled: editModeEnabled,
            isSelectionVisible: isSelectionViewVisible,
            hideWhenFocused: hideWhenFocused,
            hideWhenFocusedLocked: hideWhenFocusedLocked
        )
    }
}

private final class WindowInteractionHandler: NSView, NSMenuDelegate {
    private let editModeItem = NSMenuItem(title: "Edit Mode", action: #selector(toggleEditMode), keyEquivalent: "")
    private let manageGroupItem = NSMenuItem(title: "Manage Source Group…", action: #selector(manageSourceGroup), keyEquivalent: "")
    private let hideWhenFocusedItem = NSMenuItem(title: "Hide When Focused", action: #selector(toggleHideWhenFocused), keyEquivalent: "")
    private let stopCaptureItem = NSMenuItem(title: "Stop Capture", action: #selector(stopCapture), keyEquivalent: "")
    private let closeItem = NSMenuItem(title: "Close Window", action: #selector(closeWindow), keyEquivalent: "")
    private let contextMenu = NSMenu()

    private var editModeEnabled = false
    private var isSelectionVisible = false

    var onEditModeToggle: (() -> Void)?
    var onSourceWindowFocus: (() -> Void)?
    var onManageSourceGroup: (() -> Void)?
    var onToggleHideWhenFocused: (() -> Void)?
    var onStopCapture: (() -> Void)?
    var onCloseWindow: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        // Transparent hit target so edit-mode drag works over any SwiftUI content.
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        contextMenu.autoenablesItems = false
        for item in [editModeItem, manageGroupItem, hideWhenFocusedItem, stopCaptureItem, closeItem] {
            item.target = self
        }
        contextMenu.addItem(editModeItem)
        contextMenu.addItem(manageGroupItem)
        contextMenu.addItem(hideWhenFocusedItem)
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(stopCaptureItem)
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(closeItem)
        contextMenu.delegate = self
        menu = contextMenu
    }

    required init?(coder: NSCoder) { nil }

    func updateState(
        editModeEnabled: Bool,
        isSelectionVisible: Bool,
        hideWhenFocused: Bool,
        hideWhenFocusedLocked: Bool
    ) {
        self.editModeEnabled = editModeEnabled
        self.isSelectionVisible = isSelectionVisible
        editModeItem.state = editModeEnabled ? .on : .off
        hideWhenFocusedItem.state = hideWhenFocused ? .on : .off
        stopCaptureItem.isEnabled = !isSelectionVisible
        manageGroupItem.isEnabled = !isSelectionVisible
        hideWhenFocusedItem.isEnabled = !isSelectionVisible && !hideWhenFocusedLocked
    }

    override func mouseDown(with event: NSEvent) {
        // Borderless previews cannot rely on movableByWindowBackground once SwiftUI controls
        // sit above the content view — explicitly start a window drag in edit mode.
        if editModeEnabled {
            window?.performDrag(with: event)
            return
        }
        if !isSelectionVisible {
            onSourceWindowFocus?()
            return
        }
        super.mouseDown(with: event)
    }

    func menuWillOpen(_ menu: NSMenu) {
        stopCaptureItem.isEnabled = !isSelectionVisible
        manageGroupItem.isEnabled = !isSelectionVisible
    }

    @objc private func toggleEditMode() { onEditModeToggle?() }
    @objc private func manageSourceGroup() { onManageSourceGroup?() }
    @objc private func toggleHideWhenFocused() { onToggleHideWhenFocused?() }
    @objc private func stopCapture() { onStopCapture?() }
    @objc private func closeWindow() { onCloseWindow?() }
}
