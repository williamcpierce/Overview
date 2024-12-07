/*
 CaptureView.swift
 Overview

 Created by William Pierce on 10/13/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

struct CaptureView: View {
    @ObservedObject var captureManager: ScreenCaptureManager
    @ObservedObject var appSettings: AppSettings
    @Binding var isEditModeEnabled: Bool
    @StateObject private var viewModel = CaptureViewModel()
    let opacity: Double
    
    var body: some View {
        mainContent
            .onAppear(perform: startCapture)
            .onDisappear(perform: stopCapture)
            .alert(
                isPresented: $viewModel.showError,
                content: { CaptureAlertConfiguration.errorAlert(message: viewModel.errorMessage) }
            )
    }
    
    private var mainContent: some View {
        Group {
            if let frame = captureManager.capturedFrame {
                captureContent(frame)
            } else {
                NoCaptureView(opacity: opacity)
            }
        }
    }
    
    private func captureContent(_ frame: CapturedFrame) -> some View {
        Capture(frame: frame)
            .opacity(opacity)
            .withInteractionOverlay(
                isEditModeEnabled: $isEditModeEnabled,
                focusAction: { captureManager.focusWindow(isEditModeEnabled: isEditModeEnabled) }
            )
            .withFocusedBorder(
                isVisible: appSettings.showFocusedBorder && captureManager.isSourceWindowFocused
            )
            .withTitleOverlay(
                title: captureManager.windowTitle,
                isVisible: appSettings.showWindowTitle
            )
    }
    
    private func startCapture() {
        Task {
            await viewModel.startCapture(using: captureManager)
        }
    }
    
    private func stopCapture() {
        Task {
            await captureManager.stopCapture()
        }
    }
}

// View modifiers to clean up the overlay code
private extension View {
    func withInteractionOverlay(
        isEditModeEnabled: Binding<Bool>,
        focusAction: @escaping () -> Void
    ) -> some View {
        overlay(InteractionOverlay(
            isEditModeEnabled: isEditModeEnabled,
            isBringToFrontEnabled: true,
            bringToFrontAction: focusAction,
            toggleEditModeAction: { isEditModeEnabled.wrappedValue.toggle() }
        ))
    }
    
    func withFocusedBorder(isVisible: Bool) -> some View {
        overlay(FocusedBorderOverlay(isVisible: isVisible))
    }
    
    func withTitleOverlay(title: String?, isVisible: Bool) -> some View {
        overlay(Group {
            if isVisible, let title = title {
                WindowTitleOverlay(title: title)
            }
        })
    }
}
