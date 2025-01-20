/*
 Preview/PreviewView.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages the main preview interface, coordinating capture state, window visibility,
 and user interactions across the application's preview functionality.
*/

import SwiftUI

struct PreviewView: View {
    // Dependencies
    @Environment(\.dismiss) private var dismiss: DismissAction
    @ObservedObject private var previewManager: PreviewManager
    @ObservedObject private var sourceManager: SourceManager
    @StateObject private var captureManager: CaptureManager
    private let logger = AppLogger.interface

    // Private State
    @State private var isSelectionViewVisible: Bool = true
    @State private var isPreviewVisible: Bool = true
    @State private var previewAspectRatio: CGFloat = 0

    // Preview Settings
    @AppStorage(PreviewSettingsKeys.captureFrameRate)
    private var captureFrameRate = PreviewSettingsKeys.defaults.captureFrameRate
    @AppStorage(PreviewSettingsKeys.hideInactiveApplications)
    private var hideInactiveApplications = PreviewSettingsKeys.defaults.hideInactiveApplications
    @AppStorage(PreviewSettingsKeys.hideActiveWindow)
    private var hideActiveWindow = PreviewSettingsKeys.defaults.hideActiveWindow
    
    // Window Settings
    @AppStorage(WindowSettingsKeys.closeOnCaptureStop)
    private var closeOnCaptureStop = WindowSettingsKeys.defaults.closeOnCaptureStop

    init(previewManager: PreviewManager, sourceManager: SourceManager) {
        self.previewManager = previewManager
        self.sourceManager = sourceManager
        self._captureManager = StateObject(
            wrappedValue: CaptureManager(sourceManager: sourceManager)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            previewContentStack(in: geometry)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .aspectRatio(previewAspectRatio, contentMode: .fit)
                .background(previewBackgroundLayer)
                .background(windowConfigurationLayer)
                .overlay(previewInteractionLayer)
                .overlay(EditIndicatorOverlay(isEditModeEnabled: previewManager.editModeEnabled))
                .overlay(CloseButtonOverlay(
                    isEditModeEnabled: previewManager.editModeEnabled,
                    teardownCapture: teardownCapture
                ))
                .opacity(isPreviewVisible ? 1 : 0)
        }
        .frame(minWidth: 160, minHeight: 80)
        .onAppear(perform: setupCapture)
        .onDisappear(perform: teardownCapture)
        .onChange(of: captureManager.capturedFrame?.size) { newSize in
            updatePreviewDimensions(from: captureManager.capturedFrame?.size, to: newSize)
        }
        .onChange(of: captureManager.isCapturing) { _ in
            updateViewState()
        }
        .onChange(of: previewManager.editModeEnabled) { _ in
            updatePreviewVisibility()
        }
        .onChange(of: captureManager.isSourceAppFocused) { _ in
            updatePreviewVisibility()
        }
        .onChange(of: captureManager.isSourceWindowFocused) { _ in
            updatePreviewVisibility()
        }
        .onChange(of: sourceManager.isOverviewActive) { _ in
            updatePreviewVisibility()
        }
        .onChange(of: hideInactiveApplications) { _ in
            updatePreviewVisibility()
        }
        .onChange(of: hideActiveWindow) { _ in
            updatePreviewVisibility()
        }
        .onChange(of: captureFrameRate) { _ in
            updatePreviewFrameRate()
        }
    }

    // MARK: - View Components

    private func previewContentStack(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            if isSelectionViewVisible {
                PreviewSelection(
                    captureManager: captureManager,
                    previewManager: previewManager
                )
            } else {
                PreviewCapture(
                    captureManager: captureManager
                )
            }
        }
    }

    private var previewInteractionLayer: some View {
        WindowInteraction(
            editModeEnabled: $previewManager.editModeEnabled,
            isSelectionViewVisible: $isSelectionViewVisible,
            onEditModeToggle: { previewManager.editModeEnabled.toggle() },
            onSourceWindowFocus: { captureManager.focusSource() },
            teardownCapture: teardownCapture
        )
    }

    private var previewBackgroundLayer: some View {
        Rectangle()
            .fill(.regularMaterial)
            .opacity(isSelectionViewVisible ? 1 : 0)
    }

    private var windowConfigurationLayer: some View {
        WindowAccessor(
            aspectRatio: $previewAspectRatio,
            captureManager: captureManager,
            previewManager: previewManager,
            sourceManager: sourceManager
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
        if !captureManager.isCapturing && closeOnCaptureStop {
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
            hideInactiveApplications && !captureManager.isSourceAppFocused

        let shouldHideForActiveWindow =
            hideActiveWindow && captureManager.isSourceWindowFocused

        isPreviewVisible = !shouldHideForInactiveApps && !shouldHideForActiveWindow
    }

    private func updatePreviewFrameRate() {
        logger.info("Updating capture frame rate")
        Task {
            await captureManager.updateStreamConfiguration()
        }
    }
}
