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

    @State private var activeManagerId: UUID?
    @State private var showingSelection = true
    @State private var windowAspectRatio: CGFloat
    @State private var capturedWindowDimensions: CGSize?
    @State private var onFirstInitialization = true

    private let logger = AppLogger.interface

    init(
        appSettings: AppSettings,
        previewManager: PreviewManager
    ) {
        self.appSettings = appSettings
        self.previewManager = previewManager

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
        .onAppear(perform: initializeCaptureManager)
        .onDisappear(perform: cleanupCaptureManager)
        .onChange(of: capturedWindowDimensions) { oldValue, newValue in
            updateWindowAspectRatio(oldValue, newValue)
        }
    }

    private func previewContainer(_ geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            if showingSelection {
                SelectionView(
                    previewManager: previewManager,
                    appSettings: appSettings,
                    captureManagerId: $activeManagerId,
                    showingSelection: $showingSelection,
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
                    appSettings: appSettings,
                    captureManager: captureManager,
                    editMode: $previewManager.editMode,
                    showingSelection: $showingSelection
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
        Color.black.opacity(showingSelection ? appSettings.opacity : 0)
    }

    private var windowInteractionHandler: some View {
        InteractionOverlay(
            editMode: $previewManager.editMode,
            bringToFront: false,
            bringToFrontAction: {},
            toggleEditModeAction: { previewManager.editMode.toggle() }
        )
    }

    private var windowPropertyController: some View {
        PreviewAccessor(
            appSettings: appSettings,
            aspectRatio: $windowAspectRatio,
            isEditModeEnabled: $previewManager.editMode
        )
    }

    private func initializeCaptureManager() {
        guard !onFirstInitialization else {
            onFirstInitialization = false
            return
        }

        activeManagerId = previewManager.createNewCaptureManager()
        logger.info(
            "Created new capture manager: \(activeManagerId?.uuidString ?? "nil")")
    }

    private func cleanupCaptureManager() {
        guard !onFirstInitialization else { return }

        if let id = activeManagerId {
            logger.info(
                "ContentView disappearing, removing capture manager: \(id.uuidString)")
            previewManager.removeCaptureManager(id: id)
        }
    }

    private func updateWindowAspectRatio(_ oldSize: CGSize?, _ newSize: CGSize?) {
        if let size = newSize {
            let newAspectRatio = size.width / size.height
            logger.info("Window size changed - New aspect ratio: \(newAspectRatio)")
            windowAspectRatio = newAspectRatio
        }
    }

    private func recoverCaptureManager() {
        logger.warning("Retrying capture manager initialization")
        activeManagerId = previewManager.createNewCaptureManager()

        if let id = activeManagerId {
            logger.info("Successfully recreated capture manager: \(id.uuidString)")
        } else {
            logger.error("Failed to recreate capture manager")
        }
    }
}
