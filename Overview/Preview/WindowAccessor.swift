/*
 WindowAccessor.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages low-level window configuration through NSWindow APIs, providing
 essential window management capabilities for Overview's preview windows.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

/// Bridges SwiftUI window state with AppKit window properties for preview windows
///
/// Key responsibilities:
/// - Controls window transparency and visual properties
/// - Manages window level and collection behavior settings
/// - Maintains window aspect ratio during resizing
/// - Coordinates edit mode state transitions
///
/// Coordinates with:
/// - AppSettings: Applies window management preferences
/// - PreviewView: Synchronizes window dimensions with content
/// - ContentView: Processes edit mode state changes
/// - NSWindow: Configures low-level window behavior
struct WindowAccessor: NSViewRepresentable {
    // MARK: - Properties

    /// Current width-to-height ratio for window sizing
    /// - Note: Updated when source window dimensions change
    @Binding var aspectRatio: CGFloat

    /// Controls window interaction and chrome visibility
    /// - Note: When true, enables window controls and resizing
    @Binding var isEditModeEnabled: Bool

    /// User-configured window management settings
    /// - Note: Changes trigger immediate window updates
    @ObservedObject var appSettings: AppSettings

    // MARK: - Private Properties

    /// Rate limits window property updates
    /// - Note: Prevents performance issues during resize
    private let updateDebounceInterval: TimeInterval = 0.1

    // MARK: - NSViewRepresentable Implementation

    /// Creates the window container view with initial configuration
    ///
    /// Flow:
    /// 1. Creates base NSView instance
    /// 2. Sets up window style and behavior
    /// 3. Configures initial dimensions
    /// 4. Establishes window management behavior
    ///
    /// - Important: Window setup must occur after view creation
    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        // Context: Window configuration requires valid window reference
        DispatchQueue.main.async {
            guard let window = view.window else { return }

            // Core window configuration
            window.styleMask = [.fullSizeContentView]
            window.hasShadow = false
            window.backgroundColor = .clear
            window.isMovableByWindowBackground = true

            // Context: Auxiliary windows improve Stage Manager compatibility
            window.collectionBehavior.insert(.fullScreenAuxiliary)

            // Initial window setup
            let size = NSSize(
                width: appSettings.defaultWindowWidth,
                height: appSettings.defaultWindowHeight
            )
            window.setContentSize(size)
            window.contentMinSize = size
            window.contentAspectRatio = size
        }
        return view
    }

    /// Updates window properties when state or settings change
    ///
    /// Flow:
    /// 1. Validates window reference
    /// 2. Processes edit mode changes
    /// 3. Updates window management settings
    /// 4. Maintains aspect ratio constraints
    ///
    /// - Important: Updates are debounced for performance
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }

        // Context: Debouncing prevents rapid consecutive updates
        DispatchQueue.main.asyncAfter(deadline: .now() + updateDebounceInterval) {
            updateEditModeProperties(for: window)
            updateWindowManagement(for: window)
            updateWindowSize(for: window)
        }
    }

    // MARK: - Private Methods

    /// Updates window properties based on edit mode state
    ///
    /// Flow:
    /// 1. Configures window chrome visibility
    /// 2. Updates movement restrictions
    /// 3. Adjusts window level for positioning
    private func updateEditModeProperties(for window: NSWindow) {
        // Window chrome and interaction state
        window.styleMask =
            isEditModeEnabled ? [.fullSizeContentView, .resizable] : [.fullSizeContentView]
        window.isMovable = isEditModeEnabled

        // Context: Window level changes help with positioning in edit mode
        window.level =
            isEditModeEnabled && appSettings.enableEditModeAlignment
            ? .floating  // Behind normal windows for alignment
            : .statusBar + 1  // Above most content
    }

    /// Sets window collection behavior based on settings
    ///
    /// - Important: Affects Mission Control integration
    private func updateWindowManagement(for window: NSWindow) {
        if appSettings.managedByMissionControl {
            window.collectionBehavior.insert(.managed)
        } else {
            window.collectionBehavior.remove(.managed)
        }
    }

    /// Enforces window aspect ratio during size changes
    ///
    /// Flow:
    /// 1. Retrieves current dimensions
    /// 2. Calculates correct height
    /// 3. Updates if change is significant
    ///
    /// - Note: Ignores sub-pixel differences
    private func updateWindowSize(for window: NSWindow) {
        let currentSize = window.frame.size
        let newHeight = currentSize.width / aspectRatio

        // Context: Only update for visible changes (>1px)
        if abs(currentSize.height - newHeight) > 1.0 {
            window.setContentSize(NSSize(width: currentSize.width, height: newHeight))
            window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)
        }
    }
}
