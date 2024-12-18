/*
 ContentView.swift
 Overview

 Created by William Pierce on 9/15/24.

 Serves as the root coordinator for window preview lifecycle, managing transitions
 between window selection and preview states while maintaining proper window scaling
 and interaction handling.
*/

import SwiftUI

/// Coordinates window preview presentation and lifecycle within a single Overview window
///
/// Thread safety: Main actor only
/// Lifecycle: Created and destroyed with each Overview window
/// State transitions:
///   - Selection → Preview: When user selects a window to capture
///   - Preview → Selection: When capture fails or is stopped
///   - Edit mode: Toggles window resizing/movement capabilities
struct ContentView: View {
    @ObservedObject var previewManager: PreviewManager
    @ObservedObject var appSettings: AppSettings
    @Binding var isEditModeEnabled: Bool

    @State private var activeManagerId: UUID?
    @State private var isSelectionViewVisible = true
    @State private var windowAspectRatio: CGFloat
    @State private var capturedWindowDimensions: CGSize?

    init(
        previewManager: PreviewManager,
        isEditModeEnabled: Binding<Bool>,
        appSettings: AppSettings
    ) {
        self.previewManager = previewManager
        self._isEditModeEnabled = isEditModeEnabled
        self.appSettings = appSettings

        self._windowAspectRatio = State(
            initialValue: appSettings.defaultWindowWidth / appSettings.defaultWindowHeight
        )

        AppLogger.interface.debug(
            "ContentView initialized with default aspect ratio: \(appSettings.defaultWindowWidth / appSettings.defaultWindowHeight)"
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
        .onAppear(perform: initializeCaptureManager)
        .onDisappear(perform: cleanupCaptureManager)
        .onChange(of: capturedWindowDimensions) { oldValue, newValue in
            updateWindowAspectRatio(oldValue, newValue)
        }
    }

    private func previewContainer(_ geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            if isSelectionViewVisible {
                SelectionView(
                    previewManager: previewManager,
                    appSettings: appSettings,
                    captureManagerId: $activeManagerId,
                    showingSelection: $isSelectionViewVisible,
                    selectedWindowSize: $capturedWindowDimensions
                )
                .frame(
                    width: appSettings.defaultWindowWidth,
                    height: appSettings.defaultWindowHeight
                )
                .overlay(windowInteractionHandler)
            } else if let id = activeManagerId,
                let captureManager = previewManager.captureManagers[id]
            {
                PreviewView(
                    captureManager: captureManager,
                    appSettings: appSettings,
                    isEditModeEnabled: $isEditModeEnabled,
                    showingSelection: $isSelectionViewVisible
                )
            } else {
                managerRecoveryView
            }
        }
    }

    private var managerRecoveryView: some View {
        VStack {
            Text("No capture manager found")
                .foregroundColor(.red)
            Button("Retry") {
                recoverCaptureManager()
            }
            .padding()
        }
    }

    private var windowBackground: some View {
        Color.black.opacity(isSelectionViewVisible ? appSettings.opacity : 0)
    }

    private var windowInteractionHandler: some View {
        InteractionOverlay(
            isEditModeEnabled: $isEditModeEnabled,
            isBringToFrontEnabled: false,
            bringToFrontAction: {},
            toggleEditModeAction: { isEditModeEnabled.toggle() }
        )
    }

    private var windowPropertyController: some View {
        PreviewAccessor(
            aspectRatio: $windowAspectRatio,
            isEditModeEnabled: $isEditModeEnabled,
            appSettings: appSettings
        )
    }

    private func initializeCaptureManager() {
        AppLogger.interface.debug("ContentView appeared")
        activeManagerId = previewManager.createNewCaptureManager()
        AppLogger.interface.info(
            "Created new capture manager: \(activeManagerId?.uuidString ?? "nil")")
    }

    private func cleanupCaptureManager() {
        if let id = activeManagerId {
            AppLogger.interface.debug(
                "ContentView disappearing, removing capture manager: \(id.uuidString)")
            previewManager.removeCaptureManager(id: id)
        }
    }

    private func updateWindowAspectRatio(_ oldSize: CGSize?, _ newSize: CGSize?) {
        if let size = newSize {
            let newAspectRatio = size.width / size.height
            AppLogger.interface.debug("Window size changed - New aspect ratio: \(newAspectRatio)")
            windowAspectRatio = newAspectRatio
        }
    }

    private func recoverCaptureManager() {
        AppLogger.interface.warning("Retrying capture manager initialization")
        activeManagerId = previewManager.createNewCaptureManager()

        if let id = activeManagerId {
            AppLogger.interface.info("Successfully recreated capture manager: \(id.uuidString)")
        } else {
            AppLogger.interface.error("Failed to recreate capture manager")
        }
    }
}
