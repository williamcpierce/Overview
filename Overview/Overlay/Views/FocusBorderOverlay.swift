/*
 Overlay/Views/FocusBorderOverlay.swift
 Overview

 Created by William Pierce on 1/13/25.

 Renders a configurable focus border around preview windows when the
 source window is active.
*/

import Defaults
import SwiftUI

struct FocusBorderOverlay: View {
    // Dependencies
    private let logger = AppLogger.interface

    // Public Properties
    let isWindowFocused: Bool

    // Preview Settings
    @Default(.hideActiveWindow) private var hideActiveWindow

    // Overlay Settings
    @Default(.focusBorderEnabled) private var focusBorderEnabled
    @Default(.focusBorderWidth) private var focusBorderWidth
    @Default(.focusBorderColor) private var focusBorderColor

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
            focusBorderEnabled && isWindowFocused && !hideActiveWindow

        return shouldShow
    }
}
