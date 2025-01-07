/*
 Preview/Views/PreviewSelectionView.swift
 Overview

 Created by William Pierce on 9/15/24.

 Provides the source window selection interface allowing users to choose
 which source window to capture and preview.
*/

import ScreenCaptureKit
import SwiftUI

struct PreviewSelectionView: View {
    @ObservedObject private var appSettings: AppSettings
    @ObservedObject private var captureManager: CaptureManager
    @ObservedObject private var previewManager: PreviewManager
    @State private var selectedSource: SCWindow?
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
            sourceSelectionContent
        }
    }

    // MARK: - View Components

    private var sourceSelectionContent: some View {
        VStack {
            selectionControls
                .padding()
        }
    }

    private var selectionControls: some View {
        HStack {
            SourceListView(
                selectedSource: $selectedSource,
                sources: previewManager.availableSources,
                onSourceSelected: handleSourceSelection
            )
            .id(previewManager.sourceListVersion)
            
            refreshButton
        }
    }

    private var refreshButton: some View {
        Button(action: refreshSourceList) {
            Image(systemName: "arrow.clockwise")
        }
    }

    // MARK: - Actions

    private func refreshSourceList() {
        Task {
            await previewManager.updateAvailableSources()
        }
    }

    private func handleSourceSelection(_ source: SCWindow?) {
        if let source = source {
            previewManager.startSourcePreview(
                captureManager: captureManager,
                source: source
            )
        }
    }
}
