/*
 Preview/PreviewView.swift
 Overview

 Created by William Pierce on 9/15/24.

 Serves as the root coordinator for window preview lifecycle, managing transitions
 between window selection and preview states while maintaining proper window scaling
 and interaction handling.
*/

import SwiftUI

struct PreviewView: View {
    @ObservedObject private var captureManager: CaptureManager  // Change to ObservedObject
    @ObservedObject private var appSettings: AppSettings
    @ObservedObject private var previewManager: PreviewManager

    @State private var isSelectionViewVisible: Bool = true
    @State private var previewAspectRatio: CGFloat
    @State private var hasInitialized: Bool = false

    private let logger = AppLogger.interface

    init(appSettings: AppSettings, previewManager: PreviewManager, captureManager: CaptureManager) {
        self.appSettings = appSettings
        self.previewManager = previewManager
        self.captureManager = captureManager

        let initialRatio = appSettings.defaultWindowWidth / appSettings.defaultWindowHeight
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
        }
        .onAppear {
            setupCapture()
        }.onDisappear(perform: teardownCapture)
        .onChange(of: captureManager.capturedFrame?.size, updatePreviewDimensions)
        .onChange(of: captureManager.isCapturing, updateViewState)
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
            appSettings: appSettings,
            aspectRatio: $previewAspectRatio,
            editModeEnabled: $previewManager.editModeEnabled
        )
    }

    // MARK: - Lifecycle Methods

    private func setupCapture() {
        guard !hasInitialized else { return }
        hasInitialized = true

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
        guard let size = newSize else { return }
        let newRatio = size.width / size.height
        logger.info("Updating preview ratio: \(newRatio)")
        previewAspectRatio = newRatio
    }

    private func updateViewState() {
        isSelectionViewVisible = !captureManager.isCapturing
        logger.info("View state updated: selection=\(isSelectionViewVisible)")
    }
}
