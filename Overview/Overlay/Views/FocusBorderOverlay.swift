/*
 Overlay/Views/FocusBorderOverlay.swift
 Overview

 Created by William Pierce on 1/13/25.

 Renders a configurable focus border around preview windows when the
 source window is active.
*/

import SwiftUI

struct FocusBorderOverlay: View {
    // Dependencies
    private let logger = AppLogger.interface

    // Public Properties
    let isWindowFocused: Bool

    // Preview Settings
    @AppStorage(PreviewSettingsKeys.hideActiveWindow)
    private var previewHideActiveWindow = PreviewSettingsKeys.defaults.hideActiveWindow

    // Overlay Settings
    @AppStorage(OverlaySettingsKeys.focusBorderEnabled)
    private var focusBorderEnabled = OverlaySettingsKeys.defaults.focusBorderEnabled
    @AppStorage(OverlaySettingsKeys.focusBorderWidth)
    private var focusBorderWidth = OverlaySettingsKeys.defaults.focusBorderWidth
    @AppStorage(OverlaySettingsKeys.focusBorderColor)
    private var focusBorderColor = OverlaySettingsKeys.defaults.focusBorderColor

    var body: some View {
        Group {
            if shouldShowFocusBorder {
                focusBorder
            }
        }
    }

    // MARK: - Private Views

    private var focusBorder: some View {
        RoundedRectangle(cornerRadius: 0)
            .stroke(focusBorderColor, lineWidth: focusBorderWidth)
    }

    // MARK: - Private Properties

    private var shouldShowFocusBorder: Bool {
        let shouldShow: Bool =
            focusBorderEnabled && isWindowFocused && !previewHideActiveWindow

        return shouldShow
    }
}
