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
    @ObservedObject private var appSettings: AppSettings
    @ObservedObject private var captureManager: CaptureManager
    @ObservedObject private var previewManager: PreviewManager

    @State private var selectedWindow: SCWindow?
    @State private var windowListVersion = UUID()

    private let logger = AppLogger.interface

    init(
        appSettings: AppSettings,
        captureManager: CaptureManager,
        previewManager: PreviewManager
    ) {
        self.appSettings = appSettings
        self.captureManager = captureManager
        self.previewManager = previewManager
    }

    var body: some View {
        VStack {
            windowSelectionContent
        }
    }

    // MARK: - View Components

    private var windowSelectionContent: some View {
        VStack {
            selectionControls
                .padding()
            previewStartButton
        }
    }

    private var selectionControls: some View {
        HStack {
            windowList
            refreshButton
        }
    }

    private var windowList: some View {
        Picker("", selection: $selectedWindow) {
            Group {
                if previewManager.isInitializing {
                    loadingPlaceholder
                } else {
                    windowOptions
                }
            }
        }
        .id(windowListVersion)
        .onChange(of: selectedWindow, handleWindowSelection)
    }

    private var loadingPlaceholder: some View {
        Text("Loading...").tag(nil as SCWindow?)
    }

    private var windowOptions: some View {
        Group {
            Text("Select a window").tag(nil as SCWindow?)
            availableWindowsList
        }
    }

    private var availableWindowsList: some View {
        ForEach(captureManager.availableWindows, id: \.windowID) { window in
            Text(window.title ?? "Untitled").tag(window as SCWindow?)
        }
    }

    private var refreshButton: some View {
        Button(action: refreshWindowList) {
            Image(systemName: "arrow.clockwise")
        }
    }

    private var previewStartButton: some View {
        Button("Start Preview") {
            previewManager.startWindowPreview(
                using: captureManager,
                for: selectedWindow
            )
        }
        .disabled(selectedWindow == nil)
    }

    // MARK: - Actions

    private func refreshWindowList() {
        Task {
            logger.debug("Refreshing available windows")
            await captureManager.updateAvailableWindows()
            await MainActor.run {
                windowListVersion = UUID()
                logger.info("Window list updated: \(captureManager.availableWindows.count) windows")
            }
        }
    }

    private func handleWindowSelection(_ old: SCWindow?, _ new: SCWindow?) {
        if let window = new {
            logger.info("Selected window: '\(window.title ?? "Untitled")'")
        }
    }
}
