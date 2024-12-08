/*
 ContentView.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

/// Primary view container that manages window preview and selection states
///
/// Key responsibilities:
/// - Coordinates between selection and preview modes
/// - Manages window aspect ratio and sizing
/// - Handles edit mode interactions
///
/// Coordinates with:
/// - PreviewManager: Window management and capture state
/// - AppSettings: User preferences and window configuration
/// - SelectionView: Window selection interface
/// - PreviewView: Live window preview display
struct ContentView: View {
    // MARK: - Properties

    /// Manages capture windows and edit mode state
    @ObservedObject var previewManager: PreviewManager

    /// Stores user preferences and window settings
    @ObservedObject var appSettings: AppSettings

    /// Controls whether the window can be moved and resized
    @Binding var isEditModeEnabled: Bool

    /// State for managing the active capture session
    @State private var captureManagerId: UUID?

    /// Controls visibility of window selection interface
    @State private var showingSelection = true

    /// Current width/height ratio of the preview window
    @State private var aspectRatio: CGFloat

    /// Dimensions of the currently selected window
    @State private var selectedWindowSize: CGSize?

    // MARK: - Initialization

    /// Creates a new content view with the specified managers and edit mode state
    ///
    /// - Parameters:
    ///   - previewManager: Controls window previews and capture state
    ///   - isEditModeEnabled: Binding to edit mode toggle
    ///   - appSettings: User preferences and window configuration
    init(previewManager: PreviewManager, isEditModeEnabled: Binding<Bool>, appSettings: AppSettings)
    {
        self.previewManager = previewManager
        self._isEditModeEnabled = isEditModeEnabled
        self.appSettings = appSettings
        self._aspectRatio = State(
            initialValue: appSettings.defaultWindowWidth / appSettings.defaultWindowHeight)
    }

    // MARK: - View Body

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if showingSelection {
                    SelectionView(
                        previewManager: previewManager,
                        appSettings: appSettings,
                        captureManagerId: $captureManagerId,
                        showingSelection: $showingSelection,
                        selectedWindowSize: $selectedWindowSize
                    )
                    .frame(
                        width: appSettings.defaultWindowWidth,
                        height: appSettings.defaultWindowHeight
                    )
                } else if let id = captureManagerId,
                    let captureManager = previewManager.captureManagers[id]
                {
                    PreviewView(
                        captureManager: captureManager,
                        appSettings: appSettings,
                        isEditModeEnabled: $isEditModeEnabled,
                        showingSelection: $showingSelection
                    )
                } else {
                    retryView
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .aspectRatio(aspectRatio, contentMode: .fit)
            /// Context: Background opacity only applies during window selection
            .background(Color.black.opacity(showingSelection ? appSettings.opacity : 0))
            .overlay(
                InteractionOverlay(
                    isEditModeEnabled: $isEditModeEnabled,
                    isBringToFrontEnabled: false,
                    bringToFrontAction: {},
                    toggleEditModeAction: { isEditModeEnabled.toggle() }
                )
            )
            .background(
                WindowAccessor(
                    aspectRatio: $aspectRatio,
                    isEditModeEnabled: $isEditModeEnabled,
                    appSettings: appSettings
                )
            )
        }
        .onAppear { captureManagerId = previewManager.createNewCaptureManager() }
        .onDisappear {
            if let id = captureManagerId {
                previewManager.removeCaptureManager(id: id)
            }
        }
        .onChange(of: selectedWindowSize) { oldSize, newSize in
            if let size = newSize {
                aspectRatio = size.width / size.height
            }
        }
    }

    // MARK: - Private Views

    /// Fallback view shown when capture manager initialization fails
    private var retryView: some View {
        VStack {
            Text("No capture manager found")
                .foregroundColor(.red)
            Button("Retry") {
                captureManagerId = previewManager.createNewCaptureManager()
            }
            .padding()
        }
    }
}
