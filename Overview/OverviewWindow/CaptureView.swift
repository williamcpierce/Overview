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
    let opacity: Double

    var body: some View {
        Group {
            if let frame = captureManager.capturedFrame {
                Capture(frame: frame)
                    .opacity(opacity)
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
                        // Add border overlay when source window is focused
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.gray, lineWidth: 5)
                            .opacity(appSettings.showFocusedBorder && captureManager.isSourceWindowFocused ? 1 : 0)
                    )
            } else {
                Text("No capture available")
                    .opacity(opacity)
            }
        }
        .onAppear(perform: startCapture)
        .onDisappear(perform: stopCapture)
    }

    private func startCapture() {
        Task {
            await captureManager.startCapture()
        }
    }

    private func stopCapture() {
        Task {
            await captureManager.stopCapture()
        }
    }
}

struct Capture: NSViewRepresentable {
    let frame: CapturedFrame

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let surface = frame.surface else { return }

        let layer = CALayer()
        layer.contents = surface
        layer.contentsScale = frame.contentScale
        layer.bounds = frame.contentRect

        nsView.layer = layer
    }
}
