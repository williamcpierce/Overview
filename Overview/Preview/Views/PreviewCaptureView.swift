/*
 Preview/Views/PreviewCaptureView.swift
 Overview

 Created by William Pierce on 10/13/24.
*/

import SwiftUI

struct PreviewCaptureView: View {
    @ObservedObject private var appSettings: AppSettings
    @ObservedObject private var captureManager: CaptureManager
    private let logger = AppLogger.interface

    init(
        appSettings: AppSettings,
        captureManager: CaptureManager
    ) {
        self.appSettings = appSettings
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
        Color.black.opacity(appSettings.windowOpacity)
    }

    private func previewContent(for frame: CapturedFrame) -> some View {
        Capture(frame: frame)
            .overlay(focusBorderOverlay)
            .overlay(titleOverlay)
            .opacity(appSettings.windowOpacity)
    }

    private var focusBorderOverlay: some View {
        Group {
            if shouldShowFocusBorder {
                focusBorder
            }
        }
    }

    private var shouldShowFocusBorder: Bool {
        appSettings.showFocusedBorder && captureManager.isSourceWindowFocused
    }

    private var focusBorder: some View {
        RoundedRectangle(cornerRadius: 0)
            .stroke(appSettings.focusBorderColor, lineWidth: appSettings.focusBorderWidth)
    }

    private var titleOverlay: some View {
        Group {
            if appSettings.showWindowTitle {
                PreviewTitleView(
                    title: captureManager.windowTitle,
                    fontSize: appSettings.titleFontSize,
                    backgroundOpacity: appSettings.titleBackgroundOpacity
                )
            }
        }
    }
}
