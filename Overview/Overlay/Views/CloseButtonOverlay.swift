/*
 Overlay/Views/CloseButtonOverlay.swift
 Overview
 
 Created by William Pierce on 1/14/25.
 
 Renders a close button overlay when edit mode is enabled.
*/

import SwiftUI

struct CloseButtonOverlay: View {
    // Dependencies
    @Environment(\.dismiss) private var dismiss: DismissAction
    private let logger = AppLogger.interface
    
    // Public Properties
    let isEditModeEnabled: Bool
    let teardownCapture: () async -> Void
    
    var body: some View {
        Group {
            if isEditModeEnabled {
                VStack {
                    HStack {
                        Spacer()
                        closeButton
                    }
                    .padding(8)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Private Views
    
    private var closeButton: some View {
        Button(action: handleClose) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func handleClose() {
        logger.debug("Close button clicked, initiating window closure")
        Task {
            await teardownCapture()
            dismiss()
        }
    }
}
