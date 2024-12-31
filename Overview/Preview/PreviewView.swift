/*
 Preview/PreviewView.swift
 Overview

 Created by William Pierce on 10/13/24.

 Implements the core preview window rendering system, managing the visual presentation
 of captured window content and coordinating real-time updates between the capture
 system and user interface layers.
*/

import SwiftUI

@MainActor
struct PreviewView: View {
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
            if let frame = captureManager.capturedFrame {
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
                WindowTitleView(
                    title: captureManager.windowTitle,
                    fontSize: appSettings.titleFontSize,
                    backgroundOpacity: appSettings.titleBackgroundOpacity
                )
            }
        }
    }
}

struct WindowTitleView: View {
    private let title: String?
    private let fontSize: Double
    private let backgroundOpacity: Double

    init(
        title: String?,
        fontSize: Double = 12.0,
        backgroundOpacity: Double = 0.4
    ) {
        self.title = title
        self.fontSize = fontSize
        self.backgroundOpacity = backgroundOpacity
    }

    var body: some View {
        if let title = title {
            titleContainer(for: title)
        }
    }

    private func titleContainer(for title: String) -> some View {
        TitleContainerView(
            title: title,
            fontSize: fontSize,
            backgroundOpacity: backgroundOpacity
        )
    }
}

private struct TitleContainerView: View {
    let title: String
    let fontSize: Double
    let backgroundOpacity: Double

    var body: some View {
        VStack {
            titleBar
            Spacer()
        }
    }

    private var titleBar: some View {
        HStack {
            titleText
            Spacer()
        }
        .padding(6)
    }

    private var titleText: some View {
        Text(title)
            .font(.system(size: fontSize))
            .foregroundColor(.white)
            .padding(4)
            .background(titleBackground)
    }

    private var titleBackground: some View {
        Color.black.opacity(backgroundOpacity)
    }
}
