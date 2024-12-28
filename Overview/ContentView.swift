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
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var previewManager: PreviewManager

    @State private var captureManager: CaptureManager
    @State private var showingSelection: Bool = true
    @State private var windowAspectRatio: CGFloat
    @State private var capturedWindowDimensions: CGSize?

    private let logger = AppLogger.interface

    init(
        appSettings: AppSettings,
        previewManager: PreviewManager
    ) {
        self.appSettings = appSettings
        self.previewManager = previewManager
        self.captureManager = CaptureManager(appSettings: appSettings)
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
        .onChange(of: capturedWindowDimensions) { oldValue, newValue in
            updateWindowAspectRatio(oldValue, newValue)
        }
        .overlay(interactionLayer)
    }

    private func previewContainer(_ geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            if showingSelection {
                SelectionView(
                    appSettings: appSettings,
                    captureManager: captureManager,
                    showingSelection: $showingSelection,
                    selectedWindowSize: $capturedWindowDimensions
                )
            } else {
                PreviewView(
                    appSettings: appSettings,
                    captureManager: captureManager,
                    editModeEnabled: $previewManager.editModeEnabled,
                    showingSelection: $showingSelection
                )
            }
        }
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

    private func updateWindowAspectRatio(_ oldSize: CGSize?, _ newSize: CGSize?) {
        if let size = newSize {
            let newAspectRatio = size.width / size.height
            logger.info("Window size changed - New aspect ratio: \(newAspectRatio)")
            windowAspectRatio = newAspectRatio
        }
    }
}
