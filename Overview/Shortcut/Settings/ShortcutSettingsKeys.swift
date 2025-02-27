/*
 Shortcut/Settings/ShortcutSettingsKeys.swift
 Overview

 Created by William Pierce on 1/12/25.

 Defines storage keys for keyboard shortcut-related settings.
*/

import Foundation

enum ShortcutSettingsKeys {
    static let storedShortcuts: String = "storedShortcuts"

    static let defaults = Defaults()

    struct Defaults {
        let shortcuts: [ShortcutItem] = []
    }
}
