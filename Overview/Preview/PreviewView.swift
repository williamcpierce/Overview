/*
 Preview/PreviewView.swift
 Overview

 Created by William Pierce on 9/15/24.

 The main preview interface, coordinating capture state, window visibility,
 and user interactions across the application's preview functionality.
*/

import Defaults
import SwiftUI

struct PreviewView: View {
    // Dependencies
    @ObservedObject private var previewManager: PreviewManager
    @ObservedObject private var sourceManager: SourceManager
    @ObservedObject private var permissionManager: PermissionManager
    @ObservedObject private var captureCoordinator: CaptureCoordinator
    private let logger = AppLogger.interface
    let onClose: () -> Void

    // Private State
    @State private var isSelectionViewVisible: Bool = true
    @State private var isPreviewVisible: Bool = true
    @State private var previewAspectRatio: CGFloat = 0

    // Preview Settings
    @Default(.captureFrameRate) private var captureFrameRate
    @Default(.hideInactiveApplications) private var hideInactiveApplications
    @Default(.hideActiveWindow) private var hideActiveWindow

    // Window Settings
    @Default(.closeOnCaptureStop) private var closeOnCaptureStop

    init(
        previewManager: PreviewManager,
        sourceManager: SourceManager,
        permissionManager: PermissionManager,
        captureCoordinator: CaptureCoordinator,
        onClose: @escaping () -> Void
    ) {
        self.previewManager = previewManager
        self.sourceManager = sourceManager
        self.permissionManager = permissionManager
        self.captureCoordinator = captureCoordinator
        self.onClose = onClose
    }

    var body: some View {
        GeometryReader { geometry in
            previewContentStack(in: geometry)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .aspectRatio(previewAspectRatio, contentMode: .fit)
                .background(previewInteractionLayer)
                .background(previewBackgroundLayer)
                .background(windowConfigurationLayer)
                .overlay(EditIndicatorOverlay(isEditModeEnabled: previewManager.editModeEnabled))
                .overlay(
                    CloseButtonOverlay(
                        isEditModeEnabled: previewManager.editModeEnabled,
                        isSelectionViewVisible: isSelectionViewVisible,
                        teardownCapture: teardownCapture,
                        onClose: onClose
                    )
                )
                .opacity(isPreviewVisible ? 1 : 0)
        }
        .frame(minWidth: 100, minHeight: 50)
        .onAppear(perform: setupCapture)
        .onDisappear(perform: teardownCapture)
        .onChange(of: captureCoordinator.capturedFrame?.size) { newSize in
            updatePreviewDimensions(from: captureCoordinator.capturedFrame?.size, to: newSize)
        }
        .onChange(of: captureCoordinator.isCapturing) { _ in
            updateViewState()
        }
        .onChange(of: previewManager.editModeEnabled) { _ in
            updatePreviewVisibility()
        }
        .onChange(of: captureCoordinator.isSourceAppFocused) { _ in
            updatePreviewVisibility()
        }
        .onChange(of: captureCoordinator.isSourceWindowFocused) { _ in
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
        .onChange(of: previewManager.hideAllPreviews) { _ in
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
                    captureCoordinator: captureCoordinator,
                    previewManager: previewManager
                )
            } else {
                PreviewCapture(
                    captureCoordinator: captureCoordinator
                )
                .overlay(previewInteractionLayer)
            }
        }
    }

    private var previewInteractionLayer: some View {
        WindowInteraction(
            editModeEnabled: $previewManager.editModeEnabled,
            isSelectionViewVisible: $isSelectionViewVisible,
            onEditModeToggle: { previewManager.editModeEnabled.toggle() },
            onSourceWindowFocus: { captureCoordinator.focusSource() },
            teardownCapture: teardownCapture,
            onClose: onClose
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
            captureCoordinator: captureCoordinator,
            previewManager: previewManager,
            sourceManager: sourceManager
        )
    }

    // MARK: - Lifecycle Methods

    private func setupCapture() {
        Task {
            logger.info("Initializing capture system")
            await previewManager.initializeCaptureSystem(captureCoordinator)
        }
    }

    private func teardownCapture() {
        Task {
            logger.info("Stopping capture system")
            await captureCoordinator.stopCapture()
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
        if !captureCoordinator.isCapturing && closeOnCaptureStop {
            logger.info("Closing preview window on capture stop")
            onClose()
        }

        isSelectionViewVisible = !captureCoordinator.isCapturing
        updatePreviewVisibility()
        logger.debug("View state updated: selection=\(isSelectionViewVisible)")
    }

    private func updatePreviewVisibility() {
        if previewManager.hideAllPreviews {
            isPreviewVisible = false
            return
        }

        let alwaysShown =
            isSelectionViewVisible || previewManager.editModeEnabled
            || sourceManager.isOverviewActive

        if alwaysShown {
            isPreviewVisible = true
            return
        }

        let shouldHideForInactiveApps =
            hideInactiveApplications && !captureCoordinator.isSourceAppFocused

        let shouldHideForActiveWindow =
            hideActiveWindow && captureCoordinator.isSourceWindowFocused

        isPreviewVisible = !shouldHideForInactiveApps && !shouldHideForActiveWindow
    }

    private func updatePreviewFrameRate() {
        logger.info("Updating capture frame rate")
        Task {
            await captureCoordinator.updateStreamConfiguration()
        }
    }
}
