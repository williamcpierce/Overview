/*
 ContentView.swift
 Overview

 Created by William Pierce on 9/15/24.

 Serves as the root coordinator for window preview lifecycle, managing transitions
 between window selection and preview states while maintaining proper window scaling
 and interaction handling.
*/

import SwiftUI

struct ContentView: View {
    @StateObject private var captureManager: CaptureManager
    
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var previewManager: PreviewManager

    @State private var showingSelection: Bool = true
    @State private var windowAspectRatio: CGFloat

    private let logger = AppLogger.interface

    init(
        appSettings: AppSettings,
        previewManager: PreviewManager
    ) {
        let capture = CaptureManager(appSettings: appSettings)
        
        self.appSettings = appSettings
        self.previewManager = previewManager
        self._captureManager = StateObject(wrappedValue: capture)
        self._windowAspectRatio = State(
            initialValue: appSettings.defaultWindowWidth / appSettings.defaultWindowHeight
        )
    }

    var body: some View {
        GeometryReader { geometry in
            previewContainer(geometry)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .aspectRatio(windowAspectRatio, contentMode: .fit)
                .background(windowBackground)
                .background(windowPropertyController)
        }
        .onAppear(perform: initializeCapture)
        .onDisappear(perform: cleanupCapture)
        .onChange(of: captureManager.capturedFrame?.size) { oldValue, newValue in
            updateWindowAspectRatio(oldValue, newValue)
        }
        .onChange(of: captureManager.isCapturing, handleCaptureStateTransition)
    }

    private func previewContainer(_ geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            if showingSelection {
                SelectionView(
                    appSettings: appSettings,
                    captureManager: captureManager,
                    previewManager: previewManager
                )
            } else {
                PreviewView(
                    appSettings: appSettings,
                    captureManager: captureManager
                )
            }
        }.overlay(interactionLayer)
    }

    private var interactionLayer: some View {
        InteractionOverlay(
            editModeEnabled: $previewManager.editModeEnabled,
            showingSelection: $showingSelection,
            editModeAction: { previewManager.editModeEnabled.toggle() },
            bringToFrontAction: {
                captureManager.focusWindow()
            }
        )
    }

    private var windowBackground: some View {
        Color.black.opacity(showingSelection ? appSettings.windowOpacity : 0)
    }

    private var windowPropertyController: some View {
        PreviewAccessor(
            appSettings: appSettings,
            aspectRatio: $windowAspectRatio,
            editModeEnabled: $previewManager.editModeEnabled
        )
    }
    
    private func initializeCapture() {
        Task {
            logger.info("ContentView appeared, initializing capture")
            await previewManager.initializeCaptureSystem(captureManager: captureManager)
        }
    }

    private func cleanupCapture() {
        Task {
            logger.info("ContentView disappeared, stopping capture")
            await captureManager.stopCapture()
        }
    }
    private func updateWindowAspectRatio(_ oldSize: CGSize?, _ newSize: CGSize?) {
        if let size = newSize {
            let newAspectRatio = size.width / size.height
            logger.info("Window size changed - New aspect ratio: \(newAspectRatio)")
            windowAspectRatio = newAspectRatio
        }
    }

    private func handleCaptureStateTransition() {
        if captureManager.isCapturing {
            showingSelection = false
        } else {
            showingSelection = true
        }
        logger.info("Capture state updated, showingSelection=\(showingSelection)")
    }
}
