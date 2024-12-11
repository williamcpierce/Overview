/*
 SelectionView.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import ScreenCaptureKit
import SwiftUI

struct SelectionView: View {
    @ObservedObject var previewManager: PreviewManager
    @ObservedObject var appSettings: AppSettings
    @Binding var captureManagerId: UUID?
    @Binding var showingSelection: Bool
    @Binding var selectedWindowSize: CGSize?

    @State private var selectedWindow: SCWindow?
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var refreshID = UUID()
    @State private var availableWindows: [SCWindow] = []

    private let windowManager = WindowManager.shared

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading windows...")
            } else if let error = errorMessage.isEmpty ? nil : errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else if let captureManager = getCaptureManager() {
                windowSelectionContent(captureManager)
            }
        }
        .task {
            await setupCapture()
        }
    }

    private func windowSelectionContent(_ captureManager: CaptureManager) -> some View {
        VStack {
            HStack {
                Picker("", selection: $selectedWindow) {
                    Text("Select a window").tag(nil as SCWindow?)
                    ForEach(availableWindows, id: \.windowID) { window in
                        Text(window.title ?? "Untitled").tag(window as SCWindow?)
                    }
                }
                .id(refreshID)

                Button(action: { Task { await refreshWindows() } }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding()

            Button("Start Preview") {
                startPreview(captureManager)
            }
            .disabled(selectedWindow == nil)
        }
    }

    private func getCaptureManager() -> CaptureManager? {
        guard let id = captureManagerId else { return nil }
        return previewManager.captureManagers[id]
    }

    private func setupCapture() async {
        guard let captureManager = getCaptureManager() else {
            errorMessage = "Setup failed"
            isLoading = false
            return
        }

        do {
            try await captureManager.requestPermission()
            await refreshWindows()
            isLoading = false
        } catch {
            errorMessage = "Permission denied"
            isLoading = false
        }
    }

    private func refreshWindows() async {
        availableWindows = await windowManager.getAvailableWindows()
        await MainActor.run {
            refreshID = UUID()
        }
    }

    private func startPreview(_ captureManager: CaptureManager) {
        guard let window = selectedWindow else { return }

        captureManager.selectedWindow = window
        selectedWindowSize = CGSize(width: window.frame.width, height: window.frame.height)
        showingSelection = false

        Task {
            try? await captureManager.startCapture()
        }
    }
}
