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
    @ObservedObject private var windowManager: WindowManager
    @StateObject private var captureManager: CaptureManager

    init(appSettings: AppSettings, previewManager: PreviewManager, windowManager: WindowManager) {
        self.appSettings = appSettings
        self.previewManager = previewManager
        self.windowManager = windowManager

        self._captureManager = StateObject(
            wrappedValue: CaptureManager(
                appSettings: appSettings,
                windowManager: windowManager
            )
        )
    }
    var body: some View {
        PreviewView(
            appSettings: appSettings,
            captureManager: captureManager,
            previewManager: previewManager,
            windowManager: windowManager
        )
    }
}
