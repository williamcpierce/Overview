/*
 ContentView.swift
 Overview

 Created by William Pierce on 12/31/24.
*/

import SwiftUI

struct ContentView: View {
    @StateObject private var captureManager: CaptureManager
    let appSettings: AppSettings
    let previewManager: PreviewManager

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
