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
    @ObservedObject private var captureCoordinator: CaptureCoordinator
    private let logger = AppLogger.interface

    // Window Settings
    @AppStorage(WindowSettingsKeys.previewOpacity)
    private var previewOpacity = WindowSettingsKeys.defaults.previewOpacity

    init(captureCoordinator: CaptureCoordinator) {
        self.captureCoordinator = captureCoordinator
    }

    var body: some View {
        Group {
            if let frame: CapturedFrame = captureCoordinator.capturedFrame {
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
            .overlay(FocusBorderOverlay(isWindowFocused: captureCoordinator.isSourceWindowFocused))
            .overlay(
                TitleOverlay(
                    windowTitle: captureCoordinator.sourceWindowTitle,
                    applicationTitle: captureCoordinator.sourceApplicationTitle)
            )
            .opacity(previewOpacity)
    }
}
