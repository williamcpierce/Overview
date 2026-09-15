/*
 Source/Settings/SourceSettingsKeys.swift
 Overview

 Legacy filter keys retained so old preference values do not crash.
 Pickers are hard-limited to EVE Online via EveSourceMatcher; these keys are unused.
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
