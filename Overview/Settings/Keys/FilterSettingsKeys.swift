/*
 Settings/FilterSettingsKeys.swift
 Overview

 Created by William Pierce on 1/12/25.

 Defines storage keys for filter-related settings.
*/

enum FilterSettingsKeys {
    static let appNames = "appFilterNames"
    static let isBlocklist = "isFilterBlocklist"

    static let defaults = Defaults()

    struct Defaults {
        let appNames: [String] = []
        let isBlocklist: Bool = true
    }
}
