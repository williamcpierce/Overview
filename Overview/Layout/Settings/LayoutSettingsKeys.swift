/*
 Layout/Settings/LayoutSettingsKeys.swift
 Overview

 Created by William Pierce on 2/24/25.
*/

import Foundation

enum LayoutSettingsKeys {
    static let layouts: String = "storedLayouts"
    static let launchLayoutId: String = "launchLayoutId"
    static let applyLayoutOnLaunch: String = "applyLayoutOnLaunch"

    static let defaults = Defaults()

    struct Defaults {
        let applyLayoutOnLaunch: Bool = false
    }
}
