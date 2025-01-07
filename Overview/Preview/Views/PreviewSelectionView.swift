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
            sourceList
            refreshButton
        }
    }

    private var sourceList: some View {
        Picker("", selection: $selectedSource) {
            Text("Select a source window").tag(nil as SCWindow?)
            availableSourcesList
        }
        .id(previewManager.sourceListVersion)
        .onChange(of: selectedSource, handleSourceSelection)
    }

    private var availableSourcesList: some View {
        let groupedSources = Dictionary(
            grouping: previewManager.availableSources,
            by: { $0.owningApplication?.applicationName ?? "Unknown" }
        )

        let sortedAppNames = groupedSources.keys.sorted()

        return ForEach(sortedAppNames, id: \.self) { appName in
            if let sources = groupedSources[appName] {
                Section(header: Text(appName)) {
                    ForEach(
                        sources.sorted(by: { ($0.title ?? "") < ($1.title ?? "") }),
                        id: \.windowID
                    ) { source in
                        Text(truncateTitle(source.title ?? "Untitled"))
                            .tag(Optional(source))
                    }
                }
            }
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

    private func handleSourceSelection(_ old: SCWindow?, _ new: SCWindow?) {
        if let source: SCWindow = new {
            logger.info("Source selected: '\(source.title ?? "Untitled")'")
            previewManager.startSourcePreview(
                captureManager: captureManager,
                source: selectedSource
            )
        }
    }

    // MARK: - Helper Functions

    private func truncateTitle(_ title: String) -> String {
        title.count > 50 ? title.prefix(50) + "..." : title
    }
}
