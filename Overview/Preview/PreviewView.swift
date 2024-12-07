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

struct PreviewView: View {
    @ObservedObject var captureManager: CaptureManager
    @ObservedObject var appSettings: AppSettings
    @Binding var isEditModeEnabled: Bool
    @StateObject private var viewModel = PreviewViewModel()
    let opacity: Double
    
    var body: some View {
        mainContent
            .onAppear(perform: startCapture)
            .onDisappear(perform: stopCapture)
            .alert(
                isPresented: $viewModel.showError,
                content: { PreviewAlertConfiguration.errorAlert(message: viewModel.errorMessage) }
            )
    }
    
    private var mainContent: some View {
        Group {
            if let frame = captureManager.capturedFrame {
                captureContent(frame)
            } else {
                NoPreviewView(opacity: opacity)
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

class PreviewViewModel: ObservableObject {
    @Published var showError = false
    @Published var errorMessage = ""
    
    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
    
    func startCapture(using manager: CaptureManager) async {
        do {
            try await manager.startCapture()
        } catch {
            await MainActor.run {
                handleError(error)
            }
        }
    }
}


struct PreviewAlertConfiguration {
    static func errorAlert(message: String) -> Alert {
        Alert(
            title: Text("Error"),
            message: Text(message),
            dismissButton: .default(Text("OK"))
        )
    }
}

struct FocusedBorderOverlay: View {
    let isVisible: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 0)
            .stroke(Color.gray, lineWidth: 5)
            .opacity(isVisible ? 1 : 0)
    }
}

struct WindowTitleOverlay: View {
    let title: String
    
    var body: some View {
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

struct NoPreviewView: View {
    let opacity: Double
    
    var body: some View {
        Text("No capture available")
            .opacity(opacity)
    }
}
