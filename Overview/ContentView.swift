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

struct ContentView: View {
    @ObservedObject var previewManager: PreviewManager
    @ObservedObject var appSettings: AppSettings
    @Binding var isEditModeEnabled: Bool

    @State private var captureManagerId: UUID?
    @State private var showingSelection = true
    @State private var aspectRatio: CGFloat
    @State private var selectedWindowSize: CGSize?

    init(
        previewManager: PreviewManager,
        isEditModeEnabled: Binding<Bool>,
        appSettings: AppSettings
    ) {
        self.previewManager = previewManager
        self._isEditModeEnabled = isEditModeEnabled
        self.appSettings = appSettings
        self._aspectRatio = State(
            initialValue: appSettings.defaultWindowWidth / appSettings.defaultWindowHeight
        )
    }

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

    private var backgroundLayer: some View {
        Color.black.opacity(showingSelection ? appSettings.opacity : 0)
    }

    private var interactionLayer: some View {
        InteractionOverlay(
            isEditModeEnabled: $isEditModeEnabled,
            isBringToFrontEnabled: false,
            bringToFrontAction: {},
            toggleEditModeAction: { isEditModeEnabled.toggle() }
        )
    }

    private var windowAccessorLayer: some View {
        WindowAccessor(
            aspectRatio: $aspectRatio,
            isEditModeEnabled: $isEditModeEnabled,
            appSettings: appSettings
        )
    }

    private func handleAppear() {
        captureManagerId = previewManager.createNewCaptureManager()
    }

    private func handleDisappear() {
        if let id = captureManagerId {
            previewManager.removeCaptureManager(id: id)
        }
    }

    private func handleWindowSizeChange(_ oldSize: CGSize?, _ newSize: CGSize?) {
        if let size = newSize {
            aspectRatio = size.width / size.height
        }
    }
}
