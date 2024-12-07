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

// MARK: - ContentView
struct ContentView: View {
    // MARK: - Properties
    private struct ViewState {
        var captureManagerId: UUID?
        var showingSelection = true
        var selectedWindowSize: CGSize?
        var aspectRatio: CGFloat
        var hasSetInitialSize = false
        
        init(defaultWidth: Double, defaultHeight: Double) {
            self.aspectRatio = defaultWidth / defaultHeight
        }
    }
    
    // MARK: - Observed Properties
    @ObservedObject private var previewManager: PreviewManager
    @ObservedObject private var appSettings: AppSettings
    @Binding private var isEditModeEnabled: Bool
    
    // MARK: - State
    @State private var viewState: ViewState
    
    // MARK: - Initialization
    init(previewManager: PreviewManager, isEditModeEnabled: Binding<Bool>, appSettings: AppSettings) {
        self.previewManager = previewManager
        self._isEditModeEnabled = isEditModeEnabled
        self.appSettings = appSettings
        self._viewState = State(initialValue: ViewState(
            defaultWidth: appSettings.defaultWindowWidth,
            defaultHeight: appSettings.defaultWindowHeight
        ))
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            mainContent(in: geometry)
                .background(windowAccessor)
                .onAppear(perform: createCaptureManager)
                .onDisappear(perform: removeCaptureManager)
                .onChange(of: viewState.selectedWindowSize, updateAspectRatioForSelectedWindow)
        }
    }
    
    // MARK: - Content Builders
    @ViewBuilder
    private func mainContent(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            if viewState.showingSelection {
                selectionView
            } else {
                captureContent
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .aspectRatio(viewState.aspectRatio, contentMode: .fit)
        .background(Color.black.opacity(
            viewState.showingSelection ? appSettings.opacity : 0
        ))
        .overlay(interactionOverlay)
    }
    
    private var selectionView: some View {
        SelectionView(
            previewManager: previewManager,
            captureManagerId: bindingForCaptureManagerId,
            showingSelection: bindingForShowingSelection,
            selectedWindowSize: bindingForSelectedWindowSize,
            appSettings: appSettings
        )
        .frame(height: viewState.hasSetInitialSize ? nil : appSettings.defaultWindowHeight)
        .transition(.opacity)
        .frame(
            minWidth: viewState.hasSetInitialSize ? 0 : appSettings.defaultWindowWidth,
            minHeight: viewState.hasSetInitialSize ? 0 : appSettings.defaultWindowHeight
        )
        .onAppear {
            // Mark that we've set the initial size
            if !viewState.hasSetInitialSize {
                viewState.hasSetInitialSize = true
            }
        }
    }
    
    @ViewBuilder
    private var captureContent: some View {
        if let id = viewState.captureManagerId,
           let captureManager = previewManager.captureManagers[id] {
            PreviewView(
                captureManager: captureManager,
                appSettings: appSettings,
                isEditModeEnabled: $isEditModeEnabled,
                opacity: appSettings.opacity
            )
            .background(Color.clear)
        } else {
            noCaptureManagerView
        }
    }
    
    private var noCaptureManagerView: some View {
        VStack {
            Text("No capture manager found")
                .foregroundColor(.red)
            Button("Retry", action: createCaptureManager)
                .padding()
        }
    }
    
    private var interactionOverlay: some View {
        InteractionOverlay(
            isEditModeEnabled: $isEditModeEnabled,
            isBringToFrontEnabled: false,
            bringToFrontAction: {},
            toggleEditModeAction: { isEditModeEnabled.toggle() }
        )
    }
    
    private var windowAccessor: some View {
        WindowAccessor(
            aspectRatio: bindingForAspectRatio,
            isEditModeEnabled: $isEditModeEnabled,
            appSettings: appSettings
        )
    }
    
    // MARK: - State Bindings
    private var bindingForCaptureManagerId: Binding<UUID?> {
        Binding(
            get: { viewState.captureManagerId },
            set: { viewState.captureManagerId = $0 }
        )
    }
    
    private var bindingForShowingSelection: Binding<Bool> {
        Binding(
            get: { viewState.showingSelection },
            set: { viewState.showingSelection = $0 }
        )
    }
    
    private var bindingForSelectedWindowSize: Binding<CGSize?> {
        Binding(
            get: { viewState.selectedWindowSize },
            set: { viewState.selectedWindowSize = $0 }
        )
    }
    
    private var bindingForAspectRatio: Binding<CGFloat> {
        Binding(
            get: { viewState.aspectRatio },
            set: { viewState.aspectRatio = $0 }
        )
    }
    
    // MARK: - Actions
    private func createCaptureManager() {
        viewState.captureManagerId = previewManager.createNewCaptureManager()
    }
    
    private func removeCaptureManager() {
        if let id = viewState.captureManagerId {
            previewManager.removeCaptureManager(id: id)
        }
    }
    
    // MARK: - Update Handlers
    private func updateAspectRatioForSelectedWindow() {
        if let size = viewState.selectedWindowSize {
            viewState.aspectRatio = size.width / size.height
        }
    }
}
