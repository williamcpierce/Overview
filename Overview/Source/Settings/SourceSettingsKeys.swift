/*
 Source/Settings/SourceSettingsKeys.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import Defaults

extension Defaults.Keys {
    static let appFilterNames = Key<[String]>("appFilterNames", default: [])
    static let filterMode = Key<Bool>("isFilterBlocklist", default: FilterMode.blocklist)
}

enum FilterMode {
    static let allowlist: Bool = false
    static let blocklist: Bool = true
}
