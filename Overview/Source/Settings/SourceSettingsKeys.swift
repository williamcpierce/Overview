/*
 Source/Settings/SourceSettingsKeys.swift
 Overview

 Created by William Pierce on 1/12/25.

 Defines storage keys for source-related settings.
*/

enum SourceSettingsKeys {
    static let appNames: String = "appFilterNames"
    static let filterMode: String = "isFilterBlocklist"

    static let defaults = Defaults()

    struct Defaults {
        let appNames: [String] = []
        let filterMode: Bool = FilterMode.blocklist
    }
}

enum FilterMode {
    static let allowlist: Bool = false
    static let blocklist: Bool = true
}
