/*
 Overlay/Views/CloseButtonOverlay.swift
 Overview

 Close control for edit/selection modes without blocking window dragging.
*/
import SwiftUI

struct CloseButtonOverlay: View {
    private let logger = AppLogger.interface
    let isEditModeEnabled: Bool
    let isSelectionViewVisible: Bool
    let teardownCapture: () async -> Void
    let onClose: () -> Void

    var body: some View {
        // Intentionally no full-bleed container — callers place this with overlay(alignment:).
        if isEditModeEnabled || isSelectionViewVisible {
            Button(action: handleClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }

    private func handleClose() {
        logger.debug("Close button clicked, initiating window closure")
        Task {
            await teardownCapture()
            onClose()
        }
    }
}
