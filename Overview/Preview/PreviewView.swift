/*
 PreviewView.swift
 Overview

 Created by William Pierce on 10/13/24.

 Implements the core preview window rendering system, managing the visual presentation
 of captured window content and coordinating real-time updates between the capture
 system and user interface layers.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

/// Core view component responsible for rendering live window previews and managing preview state
///
/// Key responsibilities:
/// - Coordinates display of captured window content via Capture component
/// - Manages preview lifecycle and capture state transitions
/// - Coordinates visual overlays and interaction handlers
/// - Maintains synchronization between capture and display states
///
/// Coordinates with:
/// - CaptureManager: Provides frame data and manages capture lifecycle
/// - AppSettings: Controls visual appearance and overlay behavior
/// - InteractionOverlay: Manages mouse events and window interactions
/// - PreviewAccessor: Handles preview window property updates and scaling
struct PreviewView: View {
    // MARK: - Properties

    /// Controls capture stream and window state
    /// - Note: Updates trigger immediate preview refresh
    @ObservedObject var captureManager: CaptureManager

    /// User-configurable preview settings
    /// - Note: Changes affect all preview instances
    @ObservedObject var appSettings: AppSettings

    /// Controls window interaction mode
    /// - Note: Shared state affecting all preview windows
    /// - Warning: Must be coordinated through PreviewManager
    @Binding var isEditModeEnabled: Bool

    /// Controls view mode transitions
    /// - Note: True shows selection, false shows preview
    @Binding var showingSelection: Bool

    // MARK: - View Body

    var body: some View {
        Group {
            if let frame = captureManager.capturedFrame {
                previewContent(frame: frame)
            } else {
                // Use black placeholder to maintain visual consistency
                // during capture initialization and transitions
                Color.black
                    .opacity(appSettings.opacity)
            }
        }
        .onAppear {
            // Initialize capture when view enters window hierarchy
            Task {
                AppLogger.interface.debug("PreviewView appeared, starting capture")
                try? await captureManager.startCapture()
            }
        }
        .onDisappear {
            // Ensure proper resource cleanup when view is removed
            Task {
                AppLogger.interface.debug("PreviewView disappeared, stopping capture")
                await captureManager.stopCapture()
            }
        }
        .onChange(of: captureManager.isCapturing) { oldValue, newValue in
            handleCaptureStateChange(from: oldValue, to: newValue)
        }
    }

    // MARK: - Private Methods

    /// Constructs the main preview content hierarchy with overlays
    ///
    /// Flow:
    /// 1. Creates base Capture view for frame rendering
    /// 2. Applies global opacity settings
    /// 3. Adds interaction handling layer
    /// 4. Applies conditional visual overlays based on settings
    ///
    /// - Parameter frame: Current frame data for display
    /// - Returns: Composed view hierarchy for preview display
    /// - Important: InteractionOverlay must be above Capture to receive mouse events but below
    ///             visual overlays (focus border, title) to maintain proper visual hierarchy.
    ///             This ensures both proper event handling and correct visual presentation.
    private func previewContent(frame: CapturedFrame) -> some View {
        AppLogger.interface.debug("Rendering preview content with frame size: \(frame.size)")

        return Capture(frame: frame)
            .opacity(appSettings.opacity)
            .overlay(
                InteractionOverlay(
                    isEditModeEnabled: $isEditModeEnabled,
                    isBringToFrontEnabled: true,
                    bringToFrontAction: {
                        AppLogger.interface.info("User requested window focus")
                        captureManager.focusWindow(isEditModeEnabled: isEditModeEnabled)
                    },
                    toggleEditModeAction: {
                        AppLogger.interface.info("User toggled edit mode: \(!isEditModeEnabled)")
                        isEditModeEnabled.toggle()
                    }
                )
            )
            .overlay(
                // Focus border aids in visual tracking of active window
                // Only shown when source window has system focus
                appSettings.showFocusedBorder && captureManager.isSourceWindowFocused
                    ? RoundedRectangle(cornerRadius: 0)
                        .stroke(
                            appSettings.focusBorderColor, lineWidth: appSettings.focusBorderWidth)
                    : nil
            )
            .overlay(
                appSettings.showWindowTitle
                    ? TitleView(
                        title: captureManager.windowTitle,
                        fontSize: appSettings.titleFontSize,
                        backgroundOpacity: appSettings.titleBackgroundOpacity)
                    : nil
            )
    }

    /// Manages view state transitions when capture state changes
    ///
    /// Flow:
    /// 1. Detects capture state changes
    /// 2. Returns to selection view if capture stops
    /// 3. Ensures user can restart capture if needed
    ///
    /// - Parameters:
    ///   - oldValue: Previous capture state
    ///   - newValue: Updated capture state
    /// - Important: Prevents users from being stuck in non-functional preview
    private func handleCaptureStateChange(from oldValue: Bool, to newValue: Bool) {
        if !newValue {
            AppLogger.interface.warning("Capture stopped unexpectedly, returning to selection view")
            showingSelection = true
        }
    }
}

/// Displays window title with consistent styling in preview overlay
///
/// Key responsibilities:
/// - Renders window title with optimized visibility
/// - Maintains proper positioning and layout
/// - Handles null title states gracefully
/// - Supports customizable font size and background opacity
///
/// Coordinates with:
/// - PreviewView: Receives title content and visibility state
/// - AppSettings: Controls appearance customization
struct TitleView: View {
    // MARK: - Properties

    /// Text to display in overlay
    /// - Note: nil handled gracefully with no display
    let title: String?

    /// Font size for title text in points
    /// - Note: Defaults to 12pt if not specified
    let fontSize: Double

    /// Background opacity for title overlay
    /// - Note: Defaults to 0.4 if not specified
    let backgroundOpacity: Double

    // MARK: - Initialization

    /// Creates title view with optional customization
    /// - Parameters:
    ///   - title: Text to display (nil for no display)
    ///   - fontSize: Size of title text in points
    ///   - backgroundOpacity: Opacity of black background (0.0-1.0)
    init(
        title: String?,
        fontSize: Double = 12.0,
        backgroundOpacity: Double = 0.4
    ) {
        self.title = title
        self.fontSize = fontSize
        self.backgroundOpacity = backgroundOpacity
    }

    // MARK: - View Body

    var body: some View {
        if let title = title {
            VStack {
                HStack {
                    Text(title)
                        .font(.system(size: fontSize))
                        .foregroundColor(.white)
                        .padding(4)
                        // Semi-transparent background ensures readability
                        // while preserving content visibility
                        .background(Color.black.opacity(backgroundOpacity))
                    Spacer()
                }
                .padding(6)
                Spacer()
            }
        }
    }
}
