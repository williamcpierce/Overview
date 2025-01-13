/*
 Settings/Keys/HotkeySettingsKeys.swift
 Overview

 Created by William Pierce on 1/12/25.

 Defines storage keys for hotkey-related settings.
*/

enum HotkeySettingsKeys {
    static let bindings: String = "hotkeyBindings"

    static let defaults = Defaults()

    struct Defaults {
        let bindings: [HotkeyBinding] = []
    }
}
