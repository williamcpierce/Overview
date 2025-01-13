/*
 Preview/Views/PreviewCaptureView.swift
 Overview
 
 Created by William Pierce on 1/12/25.
*/

import SwiftUI

struct PreviewCaptureView: View {
    // MARK: - Window Settings
    @AppStorage(WindowSettingsKeys.previewOpacity)
    private var previewOpacity = WindowSettingsKeys.defaults.previewOpacity
    
    // MARK: - Overlay Settings
    @AppStorage(OverlaySettingsKeys.focusBorderEnabled)
    private var focusBorderEnabled = OverlaySettingsKeys.defaults.focusBorderEnabled
    
    @AppStorage(OverlaySettingsKeys.focusBorderWidth)
    private var focusBorderWidth = OverlaySettingsKeys.defaults.focusBorderWidth

    @AppStorage(OverlaySettingsKeys.focusBorderColor)
    private var focusBorderColor = OverlaySettingsKeys.defaults.focusBorderColor
    
    @AppStorage(OverlaySettingsKeys.sourceTitleEnabled)
    private var sourceTitleEnabled = OverlaySettingsKeys.defaults.sourceTitleEnabled
    
    @AppStorage(OverlaySettingsKeys.sourceTitleFontSize)
    private var sourceTitleFontSize = OverlaySettingsKeys.defaults.sourceTitleFontSize
    
    @AppStorage(OverlaySettingsKeys.sourceTitleBackgroundOpacity)
    private var sourceTitleBackgroundOpacity = OverlaySettingsKeys.defaults.sourceTitleBackgroundOpacity

    // MARK: - Preview Settings
    @AppStorage(PreviewSettingsKeys.hideActiveWindow)
    private var previewHideActiveWindow = PreviewSettingsKeys.defaults.hideActiveWindow
    
    // MARK: - Dependencies
    @ObservedObject private var captureManager: CaptureManager
    private let logger = AppLogger.interface

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
        Color.black.opacity(previewOpacity)
    }

    private func previewContent(for frame: CapturedFrame) -> some View {
        Capture(frame: frame)
            .overlay(focusBorderOverlay)
            .overlay(titleOverlay)
            .opacity(previewOpacity)
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
            focusBorderEnabled &&
            captureManager.isSourceWindowFocused &&
            !previewHideActiveWindow

        return shouldShow
    }

    private var focusBorder: some View {
        RoundedRectangle(cornerRadius: 0)
            .stroke(focusBorderColor, lineWidth: focusBorderWidth)
    }

    private var titleOverlay: some View {
        Group {
            if sourceTitleEnabled {
                PreviewTitleView(
                    backgroundOpacity: sourceTitleBackgroundOpacity,
                    fontSize: sourceTitleFontSize,
                    title: captureManager.sourceTitle
                )
            }
        }
    }
}
