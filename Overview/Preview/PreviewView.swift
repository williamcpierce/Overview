/*
 Preview/PreviewView.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages the main preview interface, coordinating capture state, window visibility,
 and user interactions across the application's preview functionality.
*/

import SwiftUI

struct PreviewView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss: DismissAction

    // MARK: - Dependencies
    @ObservedObject private var appSettings: AppSettings
    @ObservedObject private var captureManager: CaptureManager
    @ObservedObject private var previewManager: PreviewManager
    @ObservedObject private var sourceManager: SourceManager
    private let logger = AppLogger.interface

    // MARK: - State
    @State private var isSelectionViewVisible: Bool = true
    @State private var isPreviewVisible: Bool = true
    @State private var previewAspectRatio: CGFloat

    init(
        appSettings: AppSettings,
        captureManager: CaptureManager,
        previewManager: PreviewManager,
        sourceManager: SourceManager
    ) {
        self.appSettings = appSettings
        self.captureManager = captureManager
        self.previewManager = previewManager
        self.sourceManager = sourceManager

        self._previewAspectRatio = State(initialValue: 0)
    }

    var body: some View {
        GeometryReader { geometry in
            previewContentStack(in: geometry)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .aspectRatio(previewAspectRatio, contentMode: .fit)
                .background(previewBackgroundLayer)
                .background(windowConfigurationLayer)
                .overlay(previewInteractionLayer)
                .opacity(isPreviewVisible ? 1 : 0)
        }
        .onAppear(perform: setupCapture)
        .onDisappear(perform: teardownCapture)
        .onChange(of: captureManager.capturedFrame?.size, updatePreviewDimensions)
        .onChange(of: captureManager.isCapturing, updateViewState)
        .onChange(of: previewManager.editModeEnabled, updatePreviewVisibility)
        .onChange(of: captureManager.isSourceAppFocused, updatePreviewVisibility)
        .onChange(of: captureManager.isSourceWindowFocused, updatePreviewVisibility)
        .onChange(of: sourceManager.isOverviewActive, updatePreviewVisibility)
        .onChange(of: appSettings.previewHideInactiveApplications, updatePreviewVisibility)
        .onChange(of: appSettings.previewHideActiveWindow, updatePreviewVisibility)
    }

    // MARK: - View Components

    private func previewContentStack(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            if isSelectionViewVisible {
                PreviewSelectionView(
                    appSettings: appSettings,
                    captureManager: captureManager,
                    previewManager: previewManager
                )
            } else {
                PreviewCaptureView(
                    appSettings: appSettings,
                    captureManager: captureManager
                )
            }
        }
    }

    private var previewInteractionLayer: some View {
        PreviewInteractionOverlay(
            editModeEnabled: $previewManager.editModeEnabled,
            isSelectionViewVisible: $isSelectionViewVisible,
            onEditModeToggle: { previewManager.editModeEnabled.toggle() },
            onSourceWindowFocus: { captureManager.focusSource() }
        )
    }

    private var previewBackgroundLayer: some View {
        Color.black.opacity(isSelectionViewVisible ? appSettings.previewOpacity : 0)
    }

    private var windowConfigurationLayer: some View {
        WindowAccessor(
            aspectRatio: $previewAspectRatio,
            appSettings: appSettings,
            captureManager: captureManager,
            previewManager: previewManager
        )
    }

    // MARK: - Lifecycle Methods

    private func setupCapture() {
        Task {
            logger.info("Initializing capture system")
            await previewManager.initializeCaptureSystem(captureManager)
        }
    }

    private func teardownCapture() {
        Task {
            logger.info("Stopping capture system")
            await captureManager.stopCapture()
        }
    }

    // MARK: - State Updates

    private func updatePreviewDimensions(from oldSize: CGSize?, to newSize: CGSize?) {
        guard let size: CGSize = newSize else { return }
        let newRatio: CGFloat = size.width / size.height
        logger.debug("Updating preview dimensions: \(Int(size.width))x\(Int(size.height))")
        previewAspectRatio = newRatio
    }

    private func updateViewState() {
        if !captureManager.isCapturing && appSettings.previewCloseOnCaptureStop {
            logger.info("Closing preview window on capture stop")
            dismiss()
        }

        isSelectionViewVisible = !captureManager.isCapturing
        updatePreviewVisibility()
        logger.debug("View state updated: selection=\(isSelectionViewVisible)")
    }

    private func updatePreviewVisibility() {
        let alwaysShown =
            isSelectionViewVisible || previewManager.editModeEnabled
            || sourceManager.isOverviewActive

        if alwaysShown {
            isPreviewVisible = true
            return
        }

        let shouldHideForInactiveApps =
            appSettings.previewHideInactiveApplications && !captureManager.isSourceAppFocused

        let shouldHideForActiveWindow =
            appSettings.previewHideActiveWindow && captureManager.isSourceWindowFocused

        isPreviewVisible = !shouldHideForInactiveApps && !shouldHideForActiveWindow

        logger.debug(
            """
            Preview visibility updated: \
            visible=\(isPreviewVisible), \
            hideInactive=\(shouldHideForInactiveApps), \
            hideActive=\(shouldHideForActiveWindow)
            """)
    }
}
