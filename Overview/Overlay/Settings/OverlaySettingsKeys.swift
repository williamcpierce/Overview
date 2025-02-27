/*
 Overlay/Settings/OverlaySettingsKeys.swift
 Overview

 Created by William Pierce on 1/12/25.

 Defines storage keys for overlay-related settings.
*/

import SwiftUI

enum OverlaySettingsKeys {
    static let focusBorderEnabled: String = "showFocusedBorder"
    static let focusBorderWidth: String = "focusBorderWidth"
    static let focusBorderColor: String = "focusBorderColor"

    static let sourceTitleEnabled: String = "showWindowTitle"
    static let sourceTitleFontSize: String = "titleFontSize"
    static let sourceTitleBackgroundOpacity: String = "titleBackgroundOpacity"
    static let sourceTitleLocation: String = "windowTitleLocation"
    static let sourceTitleType: String = "sourceTitleType"

    static let defaults = Defaults()

    struct Defaults {
        let focusBorderEnabled: Bool = true
        let focusBorderWidth: Double = 5.0
        let focusBorderColor: Color = .gray

        let sourceTitleEnabled: Bool = true
        let sourceTitleFontSize: Double = 12.0
        let sourceTitleBackgroundOpacity: Double = 0.4
        let sourceTitleLocation: Bool = true
        let sourceTitleType: String = TitleType.windowTitle
    }
}

enum TitleType {
    static let windowTitle = "windowTitle"
    static let appName = "appName"
    static let fullTitle = "fullTitle"
}
