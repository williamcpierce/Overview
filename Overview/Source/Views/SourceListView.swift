/*
 Source/Views/SourceListView.swift
 Overview

 Created by William Pierce on 1/6/25.

 Provides a filtered list of available source windows organized by application
 for the preview window selection interface.
*/

import ScreenCaptureKit
import SwiftUI

struct SourceListView: View {
    @Binding var selectedSource: SCWindow?
    var sources: [SCWindow]
    let onSourceSelected: (SCWindow?) -> Void
    private let logger = AppLogger.interface

    var body: some View {
        Picker("", selection: $selectedSource) {
            Text("Select source").tag(nil as SCWindow?)
            sourcesListContent
        }
        .onChange(of: selectedSource) { newValue in
            handleSourceSelection(newValue)
        }
    }

    // MARK: - View Components

    private var sourcesListContent: some View {
        ForEach(groupedSources.keys.sorted(), id: \.self) { appName in
            if let sources: [SCWindow] = groupedSources[appName] {
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

    // MARK: - Private Methods

    private var groupedSources: [String: [SCWindow]] {
        Dictionary(
            grouping: sources,
            by: { $0.owningApplication?.applicationName ?? "Unknown" }
        )
    }

    private func handleSourceSelection(_ source: SCWindow?) {
        if let source: SCWindow = source {
            logger.info("Source selected: '\(source.title ?? "Untitled")'")
        }
        onSourceSelected(source)
    }

    private func truncateTitle(_ title: String) -> String {
        title.count > 50 ? title.prefix(50) + "..." : title
    }
}
