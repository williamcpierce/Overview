/*
 Preview/Views/PreviewSelectionView.swift
 Overview

 Created by William Pierce on 9/15/24.
*/

import ScreenCaptureKit
import SwiftUI

struct PreviewSelectionView: View {
    @ObservedObject private var appSettings: AppSettings
    @ObservedObject private var captureManager: CaptureManager
    @ObservedObject private var previewManager: PreviewManager
    @State private var selectedWindow: SCWindow?
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
        .id(previewManager.windowListVersion)
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
        ForEach(previewManager.availableWindows, id: \.windowID) { window in
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
                captureManager: captureManager,
                window: selectedWindow
            )
        }
        .disabled(selectedWindow == nil)
    }

    // MARK: - Actions

    private func refreshWindowList() {
        Task {
            logger.debug("Refreshing available windows")
            await previewManager.updateAvailableWindows()
            await MainActor.run {
                logger.info("Window list updated: \(previewManager.availableWindows.count) windows")
            }
        }
    }

    private func handleWindowSelection(_ old: SCWindow?, _ new: SCWindow?) {
        if let window: SCWindow = new {
            logger.info("Selected window: '\(window.title ?? "Untitled")'")
        }
    }
}
