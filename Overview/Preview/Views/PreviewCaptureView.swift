/*
 Preview/Views/PreviewCaptureView.swift
 Overview

 Created by William Pierce on 10/13/24.

 Renders the captured source window content with configurable overlays for
 focus borders and window titles.
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
        Color.black.opacity(appSettings.previewOpacity)
    }

    private func previewContent(for frame: CapturedFrame) -> some View {
        Capture(frame: frame)
            .overlay(focusBorderOverlay)
            .overlay(titleOverlay)
            .opacity(appSettings.previewOpacity)

    }

    private var focusBorderOverlay: some View {
        Group {
            if shouldShowFocusBorder {
                focusBorder
            }
        }
    }

    private var shouldShowFocusBorder: Bool {
        let shouldShow: Bool =
            appSettings.focusBorderEnabled && captureManager.isSourceWindowFocused
            && !appSettings.previewHideActiveWindow

        return shouldShow
    }

    private var focusBorder: some View {
        RoundedRectangle(cornerRadius: 0)
            .stroke(appSettings.focusBorderColor, lineWidth: appSettings.focusBorderWidth)
    }

    private var titleOverlay: some View {
        Group {
            if appSettings.sourceTitleEnabled {
                PreviewTitleView(
                    backgroundOpacity: appSettings.sourceTitleBackgroundOpacity,
                    fontSize: appSettings.sourceTitleFontSize,
                    title: captureManager.sourceTitle
                )
            }
        }
    }
}
