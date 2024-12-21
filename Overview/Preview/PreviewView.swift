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

    @Binding private var editMode: Bool
    @Binding private var showingSelection: Bool

    init(
        appSettings: AppSettings,
        captureManager: CaptureManager,
        editMode: Binding<Bool>,
        showingSelection: Binding<Bool>
    ) {
        self.captureManager = captureManager
        self.appSettings = appSettings
        self._editMode = editMode
        self._showingSelection = showingSelection
    }

    var body: some View {
        Group {
            if let frame = captureManager.capturedFrame {
                previewWithOverlays(frame: frame)
            } else {
                placeholderView
            }
        }
        .onAppear(perform: initializeCapture)
        .onDisappear(perform: cleanupCapture)
        .onChange(of: captureManager.isCapturing, handleCaptureStateTransition)
    }

    private var placeholderView: some View {
        Color.black.opacity(appSettings.opacity)
    }

    private func previewWithOverlays(frame: CapturedFrame) -> some View {
        Capture(frame: frame)
            .overlay(getFocusIndicatorOverlay())
            .overlay(getTitleOverlay())
            .opacity(appSettings.opacity)
            .overlay(interactionLayer)
    }

    private func getFocusIndicatorOverlay() -> AnyView {
        guard appSettings.showFocusedBorder && captureManager.isSourceWindowFocused else {
            return AnyView(EmptyView())
        }
        return AnyView(
            RoundedRectangle(cornerRadius: 0)
                .stroke(appSettings.focusBorderColor, lineWidth: appSettings.focusBorderWidth)
        )
    }

    private func getTitleOverlay() -> AnyView {
        guard appSettings.showWindowTitle else {
            return AnyView(EmptyView())
        }
        return AnyView(
            TitleView(
                title: captureManager.windowTitle,
                fontSize: appSettings.titleFontSize,
                backgroundOpacity: appSettings.titleBackgroundOpacity
            )
        )
    }

    private var interactionLayer: some View {
        InteractionOverlay(
            editMode: $editMode,
            bringToFront: true,
            bringToFrontAction: requestWindowFocus,
            toggleEditModeAction: toggleEditMode
        )
    }

    private func initializeCapture() {
        Task {
            AppLogger.interface.info("PreviewView appeared, starting capture")
            try? await captureManager.startCapture()
        }
    }

    private func cleanupCapture() {
        Task {
            AppLogger.interface.info("PreviewView disappeared, stopping capture")
            await captureManager.stopCapture()
        }
    }

    private func handleCaptureStateTransition(from oldValue: Bool, to newValue: Bool) {
        if !newValue {
            showingSelection = true
        }
    }

    private func requestWindowFocus() {
        AppLogger.interface.info("User requested window focus")
        captureManager.focusWindow(isEditModeEnabled: editMode)
    }

    private func toggleEditMode() {
        AppLogger.interface.info("User toggled edit mode: \(!editMode)")
        editMode.toggle()
    }
}

struct TitleView: View {
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
            TitleContainer(title: title, fontSize: fontSize, backgroundOpacity: backgroundOpacity)
        }
    }
}

private struct TitleContainer: View {
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
            Text(title)
                .font(.system(size: fontSize))
                .foregroundColor(.white)
                .padding(4)
                .background(Color.black.opacity(backgroundOpacity))
            Spacer()
        }
        .padding(6)
    }
}
