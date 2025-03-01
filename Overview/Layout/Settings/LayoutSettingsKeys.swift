/*
 Layout/Settings/LayoutSettingsKeys.swift
 Overview

 Created by William Pierce on 2/24/25.
*/

import Defaults
import Foundation

extension Defaults.Keys {
    static let storedLayouts = Key<Data?>("storedLayouts", default: nil)
    static let launchLayoutUUID = Key<UUID?>("launchLayoutUUID", default: nil)
    static let closeWindowsOnApply = Key<Bool>("closeWindowsOnApply", default: true)
}
