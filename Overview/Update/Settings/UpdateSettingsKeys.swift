/*
 Update/Settings/UpdateSettingsKeys.swift
 Overview

 Created by William Pierce on 2/16/25.
*/

enum UpdateSettingsKeys {
    static let enableBetaUpdates: String = "enableBetaUpdates"

    static let defaults = Defaults()

    struct Defaults {
        let enableBetaUpdates: Bool = true
    }
}
