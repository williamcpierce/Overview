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
    @ObservedObject private var windowManager: WindowManager

    // MARK: - State
    @State private var isSelectionViewVisible: Bool = true
    @State private var isWindowVisible: Bool = true
    @State private var previewAspectRatio: CGFloat
    private let logger = AppLogger.interface

    init(
        appSettings: AppSettings,
        captureManager: CaptureManager,
        previewManager: PreviewManager,
        windowManager: WindowManager
    ) {
        self.appSettings = appSettings
        self.captureManager = captureManager
        self.previewManager = previewManager
        self.windowManager = windowManager

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
                .opacity(isWindowVisible ? 1 : 0)
        }
        .onAppear(perform: setupCapture)
        .onDisappear(perform: teardownCapture)
        .onChange(of: captureManager.capturedFrame?.size, updatePreviewDimensions)
        .onChange(of: captureManager.isCapturing, updateViewState)
        .onChange(of: previewManager.editModeEnabled, updateWindowVisibility)
        .onChange(of: captureManager.isSourceAppFocused, updateWindowVisibility)
        .onChange(of: captureManager.isSourceWindowFocused, updateWindowVisibility)
        .onChange(of: windowManager.isOverviewActive, updateWindowVisibility)
        .onChange(of: appSettings.hideInactiveApplications, updateWindowVisibility)
        .onChange(of: appSettings.hideActiveWindow, updateWindowVisibility)
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
            onSourceWindowFocus: { captureManager.focusWindow() }
        )
    }

    private var previewBackgroundLayer: some View {
        Color.black.opacity(isSelectionViewVisible ? appSettings.windowOpacity : 0)
    }

    private var windowConfigurationLayer: some View {
        PreviewAccessor(
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
        if !captureManager.isCapturing && appSettings.closeOnCaptureStop {
            logger.info("Closing preview window on capture stop")
            dismiss()
        }

        isSelectionViewVisible = !captureManager.isCapturing
        updateWindowVisibility()
        logger.debug("View state updated: selection=\(isSelectionViewVisible)")
    }

    private func updateWindowVisibility() {
        let alwaysShown =
            isSelectionViewVisible || previewManager.editModeEnabled
            || windowManager.isOverviewActive

        if alwaysShown {
            isWindowVisible = true
            return
        }

        let shouldHideForInactiveApp =
            appSettings.hideInactiveApplications && !captureManager.isSourceAppFocused

        let shouldHideForActiveWindow =
            appSettings.hideActiveWindow && captureManager.isSourceWindowFocused

        isWindowVisible = !shouldHideForInactiveApp && !shouldHideForActiveWindow

        logger.debug(
            """
            Window visibility updated: \
            visible=\(isWindowVisible), \
            hideInactive=\(shouldHideForInactiveApp), \
            hideActive=\(shouldHideForActiveWindow)
            """)
    }
}
