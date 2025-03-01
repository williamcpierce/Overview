/*
 Overlay/Views/EditIndicatorOverlay.swift
 Overview

 Created by William Pierce on 1/13/25.

 Renders a visual indicator when edit mode is enabled for preview windows.
*/

import Defaults
import SwiftUI

struct EditIndicatorOverlay: View {
    // Public Properties
    let isEditModeEnabled: Bool

    // Overlay Settings
    @Default(.focusBorderColor) private var focusBorderColor

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
                .offset(x: 0.5)
        }
    }
}
