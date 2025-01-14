/*
 Preview/Views/PreviewCaptureView.swift
 Overview

 Created by William Pierce on 10/13/24.

 Renders the captured source window content with configurable overlays for
 focus borders and window titles.
*/

import SwiftUI

struct PreviewCapture: View {
    // Dependencies
    @ObservedObject private var captureManager: CaptureManager
    private let logger = AppLogger.interface

    // Window Settings
    @AppStorage(WindowSettingsKeys.previewOpacity)
    private var previewOpacity = WindowSettingsKeys.defaults.previewOpacity

    init(captureManager: CaptureManager) {
        self.captureManager = captureManager
    }

    var body: some View {
        Group {
            if let frame: CapturedFrame = captureManager.capturedFrame {
                previewContent(for: frame)
            } else {
                loadingPlaceholder
            }
        }
    }

    // MARK: - View Components

    private var loadingPlaceholder: some View {
        Rectangle()
            .fill(.regularMaterial)
    }

    private func previewContent(for frame: CapturedFrame) -> some View {
        Capture(frame: frame)
            .overlay(FocusBorderOverlay(isWindowFocused: captureManager.isSourceWindowFocused))
            .overlay(TitleOverlay(title: captureManager.sourceTitle))
            .opacity(previewOpacity)
    }
}
