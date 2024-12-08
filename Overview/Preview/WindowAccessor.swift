/*
 WindowAccessor.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

/// Manages window-level properties and behaviors for Overview preview windows
///
/// Key responsibilities:
/// - Configures basic window properties (transparency, shadow, movability)
/// - Maintains window aspect ratio based on source window
/// - Handles edit mode window behavior changes
/// - Controls window level and Mission Control integration
///
/// Coordinates with:
/// - AppSettings: For window configuration preferences
/// - ContentView: For edit mode state management
struct WindowAccessor: NSViewRepresentable {
    // MARK: - Properties

    /// Controls width/height ratio of the window
    @Binding var aspectRatio: CGFloat

    /// Determines if window can be moved/resized
    @Binding var isEditModeEnabled: Bool

    /// Contains user preferences for window behavior
    @ObservedObject var appSettings: AppSettings

    // MARK: - NSViewRepresentable Implementation

    /// Creates and configures the initial window properties
    ///
    /// Flow:
    /// 1. Creates base NSView
    /// 2. Configures window style and behavior
    /// 3. Sets initial size constraints
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                /// Set basic window properties
                window.styleMask = [.fullSizeContentView]
                window.hasShadow = false
                window.backgroundColor = .clear
                window.isMovableByWindowBackground = true
                window.collectionBehavior.insert(.fullScreenAuxiliary)

                /// Set initial size
                let size = NSSize(
                    width: appSettings.defaultWindowWidth, height: appSettings.defaultWindowHeight)
                window.setContentSize(size)
                window.contentMinSize = size
                window.contentAspectRatio = size
            }
        }
        return view
    }

    /// Updates window properties in response to state changes
    ///
    /// Flow:
    /// 1. Updates edit mode properties
    /// 2. Adjusts window management settings
    /// 3. Maintains aspect ratio constraints
    ///
    /// Context: Debounced to prevent rapid updates during window resizing
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }

        /// Debounce window updates using async dispatch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            /// Update edit mode settings
            window.styleMask =
                isEditModeEnabled ? [.fullSizeContentView, .resizable] : [.fullSizeContentView]
            window.isMovable = isEditModeEnabled
            window.level =
                isEditModeEnabled && appSettings.enableEditModeAlignment
                ? .floating : .statusBar + 1

            /// Update window management
            if appSettings.managedByMissionControl {
                window.collectionBehavior.insert(.managed)
            } else {
                window.collectionBehavior.remove(.managed)
            }

            /// WARNING: Window size updates must maintain aspect ratio to prevent display distortion
            let currentSize = window.frame.size
            let newHeight = currentSize.width / aspectRatio
            if abs(currentSize.height - newHeight) > 1.0 {
                window.setContentSize(NSSize(width: currentSize.width, height: newHeight))
                window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)
            }
        }
    }
}
