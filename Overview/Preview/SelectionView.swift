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
    @ObservedObject var previewManager: PreviewManager

    @State private var selectedWindow: SCWindow?
    @State private var windowListRefreshToken: UUID = UUID()

    private let logger = AppLogger.interface

    var body: some View {
        VStack {
            selectionInterface()
        }
    }

    private func selectionInterface() -> some View {
        VStack {
            HStack {
                windowSelectionPicker()
                refreshButton()
            }
            .padding()

            startPreviewButton()
        }
    }

    private func windowSelectionPicker() -> some View {
        Picker("", selection: $selectedWindow) {
            if previewManager.isInitializing {
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

    private func refreshButton() -> some View {
        Button(action: { Task { await refreshAvailableWindows() } }) {
            Image(systemName: "arrow.clockwise")
        }
    }

    private func startPreviewButton() -> some View {
        Button("Start Preview") {
            previewManager.initiateWindowPreview(captureManager: captureManager, window: selectedWindow)
        }
        .disabled(selectedWindow == nil)
    }

    private func refreshAvailableWindows() async {
        logger.debug("Refreshing window list")
        await captureManager.updateAvailableWindows()
        await MainActor.run {
            windowListRefreshToken = UUID()
            logger.info(
                "Window list refreshed, count: \(captureManager.availableWindows.count)")
        }
    }
}
