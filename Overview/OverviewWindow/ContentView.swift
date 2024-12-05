/*
 ContentView.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import ScreenCaptureKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var windowManager: WindowManager
    @Binding var isEditModeEnabled: Bool
    @ObservedObject var appSettings: AppSettings
    @State private var captureManagerId: UUID?
    @State private var showingSelection = true
    @State private var selectedWindowSize: CGSize?
    @State private var aspectRatio: CGFloat = 1.5  // Default aspect ratio

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if showingSelection {
                    selectionView
                } else {
                    CaptureContent()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .background(Color.black.opacity(appSettings.opacity))
            .overlay(
                InteractionOverlay(
                    isEditModeEnabled: $isEditModeEnabled,
                    isBringToFrontEnabled: false,
                    bringToFrontAction: {},
                    toggleEditModeAction: { isEditModeEnabled.toggle() }
                )
            )
        }
        .background(
            WindowAccessor(aspectRatio: $aspectRatio, isEditModeEnabled: $isEditModeEnabled, appSettings: appSettings)
        )
        .onAppear(perform: createCaptureManager)
        .onDisappear(perform: removeCaptureManager)
        .onChange(of: selectedWindowSize) {
            if let size = selectedWindowSize {
                aspectRatio = size.width / size.height
            }
        }
    }

    private var selectionView: some View {
        SelectionView(
            windowManager: windowManager,
            captureManagerId: $captureManagerId,
            showingSelection: $showingSelection,
            selectedWindowSize: $selectedWindowSize,
            appSettings: appSettings
        )
        .frame(height: appSettings.defaultWindowHeight)
        .transition(.opacity)
        .frame(minWidth: appSettings.defaultWindowWidth, minHeight: appSettings.defaultWindowHeight)
    }

    @ViewBuilder
    private func CaptureContent() -> some View {
        if let id = captureManagerId, let captureManager = windowManager.captureManagers[id] {
            CaptureView(
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

    private func createCaptureManager() {
        captureManagerId = windowManager.createNewCaptureManager()
    }

    private func removeCaptureManager() {
        if let id = captureManagerId {
            windowManager.removeCaptureManager(id: id)
        }
    }

    private func updateAspectRatio(_ size: CGSize?) {
        if let size = size {
            aspectRatio = size.width / size.height
        }
    }
}
