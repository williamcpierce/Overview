/*
 Layout/Settings/LayoutSettingsKeys.swift
 Overview

 Created by William Pierce on 2/24/25.
*/

import Foundation

enum LayoutSettingsKeys {
    static let layouts: String = "storedLayouts"
    static let launchLayoutId: String = "launchLayoutId"
    static let closeWindowsOnApply: String = "closeWindowsOnApply"

    static let defaults = Defaults()

    struct Defaults {
        let closeWindowsOnApply: Bool = true
    }
}
