/*
 SelectionView.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages window selection and capture initialization, providing the initial setup
 interface for Overview preview windows and handling permission flows.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import ScreenCaptureKit
import SwiftUI

/// Manages window selection and capture session initialization
///
/// Key responsibilities:
/// - Presents window selection interface with filtering and refresh
/// - Handles screen recording permission workflow
/// - Coordinates capture initialization with size constraints
/// - Manages transition between selection and preview modes
///
/// Coordinates with:
/// - PreviewManager: Manages capture lifecycle and window creation
/// - CaptureManager: Provides window listing and capture initialization
/// - ContentView: Coordinates window dimensions and preview state
/// - AppSettings: Applies user preferences to capture configuration
struct SelectionView: View {
    // MARK: - Properties

    /// Controls multiple window previews and edit mode state
    @ObservedObject var previewManager: PreviewManager

    /// Global application settings and preferences
    @ObservedObject var appSettings: AppSettings

    /// Active capture manager identifier
    /// - Note: Created by parent view during initialization
    @Binding var captureManagerId: UUID?

    /// Controls selection interface visibility
    /// - Note: False transitions to preview display
    @Binding var showingSelection: Bool

    /// Source window dimensions for scaling
    /// - Note: Used to maintain correct preview aspect ratio
    @Binding var selectedWindowSize: CGSize?

    // MARK: - Selection State

    /// Currently selected capture target
    /// - Note: nil indicates no window selected
    @State private var selectedWindow: SCWindow?

    /// Window list loading indicator
    /// - Note: True during permission and refresh operations
    @State private var isLoading = true

    /// Current error state message
    /// - Note: Empty string indicates no error
    @State private var errorMessage = ""

    /// Forces picker refresh on window list updates
    /// - Note: New UUID triggers picker reconstruction
    @State private var refreshID = UUID()

    // MARK: - View Layout

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading windows...")
            } else if let error = errorMessage.isEmpty ? nil : errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else if let captureManager = getCaptureManager() {
                windowSelectionContent(captureManager)
            }
        }
        .task {
            await setupCapture()
        }
    }

    // MARK: - Private Views

    /// Creates window selection interface with picker and controls
    ///
    /// Flow:
    /// 1. Displays window picker with filtered list
    /// 2. Provides refresh button for window updates
    /// 3. Shows start button for capture initiation
    ///
    /// - Parameter captureManager: Active capture manager instance
    private func windowSelectionContent(_ captureManager: CaptureManager) -> some View {
        VStack {
            HStack {
                Picker("", selection: $selectedWindow) {
                    Text("Select a window").tag(nil as SCWindow?)
                    ForEach(captureManager.availableWindows, id: \.windowID) { window in
                        Text(window.title ?? "Untitled").tag(window as SCWindow?)
                    }
                }
                .id(refreshID)

                Button(action: { Task { await refreshWindows(captureManager) } }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding()

            Button("Start Preview") {
                startPreview(captureManager)
            }
            .disabled(selectedWindow == nil)
        }
    }

    // MARK: - Private Methods

    /// Retrieves active capture manager instance
    ///
    /// - Returns: Current CaptureManager if available
    /// - Note: Used throughout view for safe manager access
    private func getCaptureManager() -> CaptureManager? {
        guard let id = captureManagerId else { return nil }
        return previewManager.captureManagers[id]
    }

    /// Initializes capture system and permissions
    ///
    /// Flow:
    /// 1. Validates capture manager reference
    /// 2. Requests screen recording permission
    /// 3. Updates available window list
    /// 4. Updates loading and error states
    ///
    /// - Important: Must complete before window selection
    private func setupCapture() async {
        guard let captureManager = getCaptureManager() else {
            errorMessage = "Setup failed"
            isLoading = false
            return
        }

        do {
            try await captureManager.requestPermission()
            await captureManager.updateAvailableWindows()
            isLoading = false
        } catch {
            // Context: Permission denied triggers settings access flow
            errorMessage = "Permission denied"
            isLoading = false
        }
    }

    /// Updates available window list
    ///
    /// Flow:
    /// 1. Requests window list refresh
    /// 2. Forces picker update with new ID
    ///
    /// - Parameter captureManager: Active manager instance
    private func refreshWindows(_ captureManager: CaptureManager) async {
        await captureManager.updateAvailableWindows()
        await MainActor.run {
            refreshID = UUID()
        }
    }

    /// Starts window capture and preview display
    ///
    /// Flow:
    /// 1. Updates manager with selected window
    /// 2. Sets parent view window dimensions
    /// 3. Transitions to preview mode
    /// 4. Initiates capture stream
    ///
    /// - Parameter captureManager: Active manager instance
    /// - Warning: Must be called from main actor context
    private func startPreview(_ captureManager: CaptureManager) {
        guard let window = selectedWindow else { return }

        captureManager.selectedWindow = window
        selectedWindowSize = CGSize(width: window.frame.width, height: window.frame.height)
        showingSelection = false

        Task {
            try? await captureManager.startCapture()
        }
    }
}
