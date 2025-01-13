/*
 ContentView.swift
 Overview

 Created by William Pierce on 12/31/24.

 The root view of the application, responsible for coordinating the preview interface
 and its dependencies.
*/

import SwiftUI

struct ContentView: View {
    @ObservedObject private var previewManager: PreviewManager
    @ObservedObject private var sourceManager: SourceManager
    @StateObject private var captureManager: CaptureManager

    init(previewManager: PreviewManager, sourceManager: SourceManager) {
        self.previewManager = previewManager
        self.sourceManager = sourceManager

        self._captureManager = StateObject(
            wrappedValue: CaptureManager(
                sourceManager: sourceManager
            )
        )
    }
    var body: some View {
        PreviewView(
            captureManager: captureManager,
            previewManager: previewManager,
            sourceManager: sourceManager
        ).frame(minWidth: 160, minHeight: 80)
    }
}
