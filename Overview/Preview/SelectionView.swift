/*
 Preview/SelectionView.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages window selection and capture initialization, providing the initial setup
 interface for Overview preview windows and handling permission flows.
*/

import ScreenCaptureKit
import SwiftUI

struct SelectionView: View {
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var captureManager: CaptureManager

    @Binding var showingSelection: Bool
    @Binding var selectedWindowSize: CGSize?

    @State private var selectedWindow: SCWindow?
    @State private var isInitializing: Bool = true
    @State private var initializationError: String = ""
    @State private var windowListRefreshToken: UUID = UUID()
    @State private var firstInitialization: Bool = true

    private let logger = AppLogger.interface

    var body: some View {
        VStack {
            if let error = initializationError.isEmpty ? nil : initializationError {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else {
                selectionInterface(captureManager)
            }
        }
        .task {
            await initializeCaptureSystem()
        }
    }

    private func selectionInterface(_ captureManager: CaptureManager) -> some View {
        VStack {
            HStack {
                windowSelectionPicker(captureManager)
                refreshButton(captureManager)
            }
            .padding()

            startPreviewButton(captureManager)
        }
    }

    private func windowSelectionPicker(_ captureManager: CaptureManager) -> some View {
        Picker("", selection: $selectedWindow) {
            if isInitializing {
                Text("Loading...").tag(nil as SCWindow?)
            } else {
                Text("Select a window").tag(nil as SCWindow?)
                ForEach(captureManager.availableWindows, id: \.windowID) { window in
                    Text(window.title ?? "Untitled").tag(window as SCWindow?)
                }
            }
        }
        .id(windowListRefreshToken)
        .onChange(of: selectedWindow) { oldValue, newValue in
            if let window = newValue {
                logger.info("Window selected: '\(window.title ?? "Untitled")'")
            }
        }
    }

    private func refreshButton(_ captureManager: CaptureManager) -> some View {
        Button(action: { Task { await refreshAvailableWindows(captureManager) } }) {
            Image(systemName: "arrow.clockwise")
        }
    }

    private func startPreviewButton(_ captureManager: CaptureManager) -> some View {
        Button("Start Preview") {
            initiateWindowPreview(captureManager)
        }
        .disabled(selectedWindow == nil)
    }

    private func initializeCaptureSystem() async {
        guard !firstInitialization else {
            firstInitialization = false
            return
        }

        do {
            try await captureManager.requestPermission()
            await captureManager.updateAvailableWindows()

            logger.info("Capture setup completed successfully")
            isInitializing = false
        } catch {
            logger.logError(
                error,
                context: "Screen recording permission request")
            initializationError = "Permission denied"
            isInitializing = false
        }
    }

    private func refreshAvailableWindows(_ captureManager: CaptureManager) async {
        logger.debug("Refreshing window list")
        await captureManager.updateAvailableWindows()
        await MainActor.run {
            windowListRefreshToken = UUID()
            logger.info(
                "Window list refreshed, count: \(captureManager.availableWindows.count)")
        }
    }

    @MainActor
    private func initiateWindowPreview(_ captureManager: CaptureManager) {
        guard let window = selectedWindow else {
            logger.warning("Attempted to start preview without window selection")
            return
        }

        logger.debug("Starting preview for window: '\(window.title ?? "Untitled")'")

        captureManager.selectedWindow = window
        selectedWindowSize = CGSize(width: window.frame.width, height: window.frame.height)
        showingSelection = false

        Task {
            do {
                try await captureManager.startCapture()
                logger.info("Preview started successfully")
            } catch {
                logger.logError(
                    error,
                    context: "Starting window preview")
            }
        }
    }
}
