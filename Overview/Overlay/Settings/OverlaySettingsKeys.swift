/*
 Overlay/Settings/OverlaySettingsKeys.swift
 Overview

 Created by William Pierce on 1/12/25.

 Defines keys for overlay-related settings.
*/

import Defaults
import SwiftUI

extension Defaults.Keys {
    // Focus Border Settings
    static let focusBorderEnabled = Key<Bool>("showFocusedBorder", default: true)
    static let focusBorderWidth = Key<Double>("focusBorderWidth", default: 5.0)
    static let focusBorderColor = Key<Color>("focusBorderColor", default: .gray)

    // Source Title Settings
    static let sourceTitleEnabled = Key<Bool>("showWindowTitle", default: true)
    static let sourceTitleFontSize = Key<Double>("titleFontSize", default: 12.0)
    static let sourceTitleBackgroundOpacity = Key<Double>("titleBackgroundOpacity", default: 0.4)
    static let sourceTitleLocation = Key<Bool>("windowTitleLocation", default: true)
    static let sourceTitleType = Key<TitleType>("sourceTitleType", default: .windowTitle)
}

enum TitleType: String, Defaults.Serializable {
    case windowTitle = "windowTitle"
    case appName = "appName"
    case fullTitle = "fullTitle"
}
