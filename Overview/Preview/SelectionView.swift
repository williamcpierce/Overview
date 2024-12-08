/*
 SelectionView.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import ScreenCaptureKit
import SwiftUI

/// Handles window selection and capture initialization for Overview previews
///
/// Key responsibilities:
/// - Displays available windows for capture selection
/// - Manages capture permission requests
/// - Initiates window capture sessions
///
/// Coordinates with:
/// - PreviewManager: For capture manager lifecycle and edit mode state
/// - CaptureManager: For window listing and capture initialization
/// - ContentView: For window size and preview state management
struct SelectionView: View {
    // MARK: - Properties

    /// Manager for coordinating multiple capture preview instances
    @ObservedObject var previewManager: PreviewManager

    /// Application-wide settings and preferences
    @ObservedObject var appSettings: AppSettings

    /// Context: These bindings coordinate window lifecycle with ContentView
    @Binding var captureManagerId: UUID?
    @Binding var showingSelection: Bool
    @Binding var selectedWindowSize: CGSize?

    /// State for window selection UI
    @State private var selectedWindow: SCWindow?
    @State private var isLoading = true
    @State private var errorMessage = ""

    /// Triggers picker refresh when window list updates
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

    // MARK: - Private Methods

    /// Renders the window selection picker and capture controls
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

    /// Retrieves the active CaptureManager instance
    private func getCaptureManager() -> CaptureManager? {
        guard let id = captureManagerId else { return nil }
        return previewManager.captureManagers[id]
    }

    /// Initializes capture permissions and available window list
    ///
    /// Flow:
    /// 1. Requests screen recording permission if needed
    /// 2. Updates available window list
    /// 3. Updates loading state
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
            errorMessage = "Permission denied"
            isLoading = false
        }
    }

    /// Updates the list of available windows and triggers picker refresh
    private func refreshWindows(_ captureManager: CaptureManager) async {
        await captureManager.updateAvailableWindows()
        await MainActor.run {
            refreshID = UUID()
        }
    }

    /// Initiates window capture and transitions to preview mode
    ///
    /// Flow:
    /// 1. Updates CaptureManager with selected window
    /// 2. Updates parent view with window dimensions
    /// 3. Transitions to preview display
    /// 4. Starts capture stream
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
