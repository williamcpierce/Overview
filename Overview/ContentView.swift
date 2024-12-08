/*
 ContentView.swift
 Overview

 Created by William Pierce on 9/15/24.

 Primary container that coordinates window preview lifecycle between selection and
 preview states, serving as the bridge for window management operations.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

/// Primary view container managing window preview lifecycle and state transitions
///
/// Key responsibilities:
/// - Coordinates window selection and preview mode transitions
/// - Maintains window aspect ratio and size constraints
/// - Manages capture manager instance lifecycle
/// - Handles window interaction state (edit mode, focus)
///
/// Coordinates with:
/// - PreviewManager: Global preview state and edit mode coordination
/// - CaptureManager: Window capture and preview state management
/// - SelectionView: Window selection and setup flow
/// - PreviewView: Live window preview display
/// - WindowAccessor: Window property management
struct ContentView: View {
    // MARK: - Properties

    /// Global preview manager coordinating window capture instances
    /// - Note: Shared across all Overview windows
    @ObservedObject var previewManager: PreviewManager

    /// Application settings for window configuration and behavior
    @ObservedObject var appSettings: AppSettings

    /// Controls window editing capabilities (move/resize)
    /// - Note: Bound to global edit mode state in PreviewManager
    @Binding var isEditModeEnabled: Bool

    // MARK: - Window State

    /// Unique identifier for this window's capture manager
    /// - Note: Created during view lifecycle, removed on disappear
    @State private var captureManagerId: UUID?

    /// Controls visibility of window selection interface
    /// - Note: True during initial setup and when capture stops
    @State private var showingSelection = true

    /// Current width/height ratio for window scaling
    /// - Note: Updated when window selection changes
    @State private var aspectRatio: CGFloat

    /// Dimensions of the currently selected source window
    /// - Note: Used to calculate correct preview scaling
    @State private var selectedWindowSize: CGSize?

    // MARK: - Initialization

    /// Creates a content view with required managers and edit mode state
    ///
    /// Flow:
    /// 1. Stores manager references for preview and settings
    /// 2. Configures initial aspect ratio from settings
    /// 3. Binds to global edit mode state
    ///
    /// - Parameters:
    ///   - previewManager: Controls window previews and capture state
    ///   - isEditModeEnabled: Binding to global edit mode toggle
    ///   - appSettings: User preferences and window configuration
    init(
        previewManager: PreviewManager,
        isEditModeEnabled: Binding<Bool>,
        appSettings: AppSettings
    ) {
        self.previewManager = previewManager
        self._isEditModeEnabled = isEditModeEnabled
        self.appSettings = appSettings

        // Use settings-defined aspect ratio until window selection
        self._aspectRatio = State(
            initialValue: appSettings.defaultWindowWidth / appSettings.defaultWindowHeight
        )
    }

    // MARK: - View Layout

    var body: some View {
        GeometryReader { geometry in
            mainContent(geometry)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .background(backgroundLayer)
                .overlay(interactionLayer)
                .background(windowAccessorLayer)
        }
        .onAppear(perform: handleAppear)
        .onDisappear(perform: handleDisappear)
        .onChange(of: selectedWindowSize) { oldValue, newValue in
            handleWindowSizeChange(oldValue, newValue)
        }
    }

    // MARK: - Private Views

    /// Main content container switching between selection and preview
    /// - Parameter geometry: Current geometry proxy from parent
    private func mainContent(_ geometry: GeometryProxy) -> some View {
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
    }

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

    /// Window background with configurable opacity
    private var backgroundLayer: some View {
        Color.black.opacity(showingSelection ? appSettings.opacity : 0)
    }

    /// Mouse event and context menu handling layer
    private var interactionLayer: some View {
        InteractionOverlay(
            isEditModeEnabled: $isEditModeEnabled,
            isBringToFrontEnabled: false,
            bringToFrontAction: {},
            toggleEditModeAction: { isEditModeEnabled.toggle() }
        )
    }

    /// Window property management and aspect ratio handling
    private var windowAccessorLayer: some View {
        WindowAccessor(
            aspectRatio: $aspectRatio,
            isEditModeEnabled: $isEditModeEnabled,
            appSettings: appSettings
        )
    }

    // MARK: - Event Handlers

    /// Creates new capture manager instance on view appear
    private func handleAppear() {
        captureManagerId = previewManager.createNewCaptureManager()
    }

    /// Removes capture manager instance on view disappear
    private func handleDisappear() {
        if let id = captureManagerId {
            previewManager.removeCaptureManager(id: id)
        }
    }

    /// Updates aspect ratio when window dimensions change
    /// - Important: Maintains source window proportions for proper display
    private func handleWindowSizeChange(_ oldSize: CGSize?, _ newSize: CGSize?) {
        if let size = newSize {
            aspectRatio = size.width / size.height
        }
    }
}
