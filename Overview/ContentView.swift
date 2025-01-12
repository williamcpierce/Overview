/*
 ContentView.swift
 Overview

 Created by William Pierce on 12/31/24.

 The root view of the application, responsible for coordinating the preview interface
 and its dependencies.
*/

import SwiftUI

struct ContentView: View {
    @ObservedObject private var appSettings: AppSettings
    @ObservedObject private var previewManager: PreviewManager
    @ObservedObject private var sourceManager: SourceManager
    @StateObject private var captureManager: CaptureManager

    init(appSettings: AppSettings, previewManager: PreviewManager, sourceManager: SourceManager) {
        self.appSettings = appSettings
        self.previewManager = previewManager
        self.sourceManager = sourceManager

        self._captureManager = StateObject(
            wrappedValue: CaptureManager(
                appSettings: appSettings,
                sourceManager: sourceManager
            )
        )
    }
    var body: some View {
        PreviewView(
            appSettings: appSettings,
            captureManager: captureManager,
            previewManager: previewManager,
            sourceManager: sourceManager
        ).frame(minWidth: 160, minHeight: 80)
    }
}
