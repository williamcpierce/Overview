/*
 Overlay/Views/EditIndicatorOverlay.swift
 Overview

 Created by William Pierce on 1/13/25.

 Renders a visual indicator when edit mode is enabled for preview windows.
*/

import SwiftUI

struct EditIndicatorOverlay: View {
    // Public Properties
    let isEditModeEnabled: Bool

    // Overlay Settings
    @AppStorage(OverlaySettingsKeys.focusBorderColor)
    private var focusBorderColor = OverlaySettingsKeys.defaults.focusBorderColor

    var body: some View {
        Group {
            if isEditModeEnabled {
                VStack {
                    Spacer()
                    indicator
                }
            }
        }
    }

    // MARK: - Private Views

    private var indicator: some View {
        HStack {
            Spacer()
            Image(systemName: "righttriangle.fill")
                .font(.caption)
                .foregroundColor(focusBorderColor)
        }
    }
}
