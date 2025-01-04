/*
 Preview/PreviewView.swift
 Overview

 Created by William Pierce on 9/15/24..
*/

import SwiftUI

struct PreviewView: View {
    @ObservedObject private var appSettings: AppSettings
    @ObservedObject private var captureManager: CaptureManager
    @ObservedObject private var previewManager: PreviewManager
    @ObservedObject private var windowManager: WindowManager
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

        let initialRatio: CGFloat = appSettings.defaultWindowWidth / appSettings.defaultWindowHeight
        self._previewAspectRatio = State(initialValue: initialRatio)
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
        .onChange(of: captureManager.isSourceAppFocused, updateWindowVisibility)
        .onChange(of: windowManager.isOverviewActive, updateWindowVisibility)
        .onChange(of: appSettings.hideInactiveWindows, updateWindowVisibility)
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
        logger.info("Updating preview ratio: \(newRatio)")
        previewAspectRatio = newRatio
    }

    private func updateViewState() {
        isSelectionViewVisible = !captureManager.isCapturing
        updateWindowVisibility()
        logger.info("View state updated: selection=\(isSelectionViewVisible)")
    }

    private func updateWindowVisibility() {
        if appSettings.hideInactiveWindows {
            isWindowVisible =
                captureManager.isSourceAppFocused || isSelectionViewVisible
                || previewManager.editModeEnabled || windowManager.isOverviewActive
            logger.debug(
                "Window visibility updated: visible=\(isWindowVisible)"
            )
        } else {
            isWindowVisible = true
        }
    }
}
