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

    init(previewManager: PreviewManager, isEditModeEnabled: Binding<Bool>, appSettings: AppSettings)
    {
        self.previewManager = previewManager
        self._isEditModeEnabled = isEditModeEnabled
        self.appSettings = appSettings
        self._aspectRatio = State(
            initialValue: appSettings.defaultWindowWidth / appSettings.defaultWindowHeight)
    }

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
