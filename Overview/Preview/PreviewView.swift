/*
 PreviewView.swift
 Overview

 Created by William Pierce on 10/13/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

/// Renders the live window preview with configurable overlays and interaction handlers
///
/// Key responsibilities:
/// - Displays the captured window content with configurable opacity
/// - Manages window focus and edit mode interactions
/// - Shows optional window title and focus border overlays
///
/// Coordinates with:
/// - CaptureManager: For frame capture and window focus state
/// - AppSettings: For visual configuration and behavior settings
struct PreviewView: View {
    @ObservedObject var captureManager: CaptureManager
    @ObservedObject var appSettings: AppSettings
    @Binding var isEditModeEnabled: Bool
    @Binding var showingSelection: Bool

    var body: some View {
        Group {
            if let frame = captureManager.capturedFrame {
                Capture(frame: frame)
                    .opacity(appSettings.opacity)
                    .overlay(
                        InteractionOverlay(
                            isEditModeEnabled: $isEditModeEnabled,
                            isBringToFrontEnabled: true,
                            bringToFrontAction: {
                                captureManager.focusWindow(isEditModeEnabled: isEditModeEnabled)
                            },
                            toggleEditModeAction: { isEditModeEnabled.toggle() }
                        )
                    )
                    .overlay(
                        appSettings.showFocusedBorder && captureManager.isSourceWindowFocused
                            ? RoundedRectangle(cornerRadius: 0).stroke(Color.gray, lineWidth: 5)
                            : nil
                    )
                    .overlay(
                        appSettings.showWindowTitle
                            ? TitleView(title: captureManager.windowTitle) : nil
                    )
            } else {
                /// Show placeholder when no frame is available
                Color.black
                    .opacity(appSettings.opacity)
            }
        }
        .onAppear {
            Task { try? await captureManager.startCapture() }
        }
        .onDisappear {
            Task { await captureManager.stopCapture() }
        }
        .onChange(of: captureManager.isCapturing) { oldValue, newValue in
            /// Return to selection view if capture stops
            if !newValue {
                showingSelection = true
            }
        }
    }
}

/// Displays the window title in a semi-transparent overlay at the top of the preview
///
/// Key responsibilities:
/// - Renders the window title with consistent styling
/// - Maintains proper layout and spacing
struct TitleView: View {
    let title: String?

    var body: some View {
        if let title = title {
            VStack {
                HStack {
                    Text(title)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.4))
                    Spacer()
                }
                .padding(6)
                Spacer()
            }
        }
    }
}
