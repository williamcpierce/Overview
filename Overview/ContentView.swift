/*
 ContentView.swift
 Overview

 Created by William Pierce on 12/31/24.
*/

import SwiftUI

struct ContentView: View {
    @ObservedObject private var appSettings: AppSettings
    @ObservedObject private var previewManager: PreviewManager
    @StateObject private var captureManager: CaptureManager

    init(appSettings: AppSettings, previewManager: PreviewManager) {
        self.appSettings = appSettings
        self.previewManager = previewManager
        self._captureManager = StateObject(wrappedValue: CaptureManager(appSettings: appSettings))
    }

    var body: some View {
        PreviewView(
            appSettings: appSettings,
            previewManager: previewManager,
            captureManager: captureManager
        )
    }
}
