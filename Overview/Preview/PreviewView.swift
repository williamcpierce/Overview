/*
 PreviewView.swift
 Overview

 Created by William Pierce on 10/13/24.

 Implements the core preview window rendering system, managing the visual presentation
 of captured window content and coordinating real-time updates between the capture
 system and user interface layers.

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
    @Binding var showingSelection: Bool
    
    var body: some View {
        Group {
            if let frame = captureManager.capturedFrame {
                previewContent(frame: frame)
            } else {
                Color.black
                    .opacity(appSettings.opacity)
            }
        }
        .onAppear {
            Task { try? await captureManager.startCapture() }
        }
        .onDisappear {
            Task { await captureManager.stopCapture() }
        }
        .onChange(of: captureManager.isCapturing) { oldValue, newValue in
            handleCaptureStateChange(from: oldValue, to: newValue)
        }
    }
    
    private func previewContent(frame: CapturedFrame) -> some View {
        Capture(frame: frame)
            .opacity(appSettings.opacity)
            .overlay(
                InteractionOverlay(
                    isEditModeEnabled: $isEditModeEnabled,
                    isBringToFrontEnabled: true,
                    bringToFrontAction: {
                        captureManager.focusWindow(isEditModeEnabled: isEditModeEnabled)
                    },
                    toggleEditModeAction: { isEditModeEnabled.toggle() }
                )
            )
            .overlay(
                appSettings.showFocusedBorder && captureManager.isSourceWindowFocused
                    ? RoundedRectangle(cornerRadius: 0).stroke(Color.gray, lineWidth: 5)
                    : nil
            )
            .overlay(alignment: .top) {
                if appSettings.showWindowTitle {
                    TitleOverlay(captureManager: captureManager)
                }
            }
    }
    
    private func handleCaptureStateChange(from oldValue: Bool, to newValue: Bool) {
        if !newValue {
            showingSelection = true
        }
    }
}

struct TitleOverlay: View {
    @ObservedObject var captureManager: CaptureManager
    
    var body: some View {
        let title = captureManager.windowTitle
        print("TitleOverlay - Rendering with title: \(title ?? "none")")
        
        return VStack {
            if let title = title {
                HStack {
                    Text(title)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.4))
                    Spacer()
                }
                .padding(6)
            }
            Spacer()
        }
    }
}
