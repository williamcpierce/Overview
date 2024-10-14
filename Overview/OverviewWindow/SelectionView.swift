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
    // MARK: - Properties
    @ObservedObject var windowManager: WindowManager
    @Binding var captureManagerId: UUID?
    @Binding var showingSelection: Bool
    @Binding var selectedWindowSize: CGSize?
    @ObservedObject var appSettings: AppSettings  // Add this line

    @State private var selectedWindow: SCWindow?
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""

    // MARK: - Body
    var body: some View {
        VStack {
            if isLoading {
                loadingView
            } else if let captureManager = getCaptureManager() {
                contentView(for: captureManager)
            } else {
                errorView(message: "Error: No capture manager found")
            }
        }
        .onAppear {
            Task { await setupCaptureManager() }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"), message: Text(errorMessage),
                dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Subviews
    private var loadingView: some View {
        ProgressView("Loading available windows...")
    }

    private func contentView(for captureManager: ScreenCaptureManager) -> some View {
        Group {
            if captureManager.availableWindows.isEmpty {
                Text("No windows available for capture")
            } else {
                windowPicker(for: captureManager)
            }
        }
    }

    private func windowPicker(for captureManager: ScreenCaptureManager) -> some View {
        VStack {
            Picker("Select Window", selection: $selectedWindow) {
                Text("None").tag(nil as SCWindow?)
                ForEach(captureManager.availableWindows, id: \.self) { window in
                    Text(window.title ?? "Untitled Window").tag(window as SCWindow?)
                }
            }
            .padding()

            Button("Confirm") {
                confirmSelection(for: captureManager)
            }
            .disabled(selectedWindow == nil)
        }
    }

    private func errorView(message: String) -> some View {
        Text(message)
            .foregroundColor(.red)
            .padding()
    }

    // MARK: - Helper Methods
    private func getCaptureManager() -> ScreenCaptureManager? {
        guard let id = captureManagerId else { return nil }
        return windowManager.captureManagers[id]
    }

    private func confirmSelection(for captureManager: ScreenCaptureManager) {
        captureManager.selectedWindow = selectedWindow
        if let window = selectedWindow {
            selectedWindowSize = CGSize(width: window.frame.width, height: window.frame.height)
        }
        showingSelection = false
        Task { await captureManager.startCapture() }
    }

    private func setupCaptureManager() async {
        guard let captureManager = getCaptureManager() else {
            showError(message: "Error: No capture manager found")
            return
        }

        let authorized = await captureManager.requestPermission()
        if authorized {
            await captureManager.updateAvailableWindows()
        } else {
            showError(message: "Screen capture permission denied")
        }

        await MainActor.run { isLoading = false }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
