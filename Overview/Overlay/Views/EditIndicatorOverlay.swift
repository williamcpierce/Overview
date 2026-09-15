/*
 Overlay/Views/EditIndicatorOverlay.swift
 Overview

 Corner cue for edit mode that does not intercept drag gestures.
*/
import Defaults
import SwiftUI

struct EditIndicatorOverlay: View {
    let isEditModeEnabled: Bool
    @Default(.focusBorderColor) private var focusBorderColor

    var body: some View {
        if isEditModeEnabled {
            Image(systemName: "righttriangle.fill")
                .font(.caption)
                .foregroundColor(focusBorderColor)
                .offset(x: 0.5)
                .allowsHitTesting(false)
        }
    }
}
