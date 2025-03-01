/*
 Shortcut/Settings/ShortcutSettingsKeys.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import Defaults
import Foundation

extension Defaults.Keys {
    static let storedShortcuts = Key<Data?>("storedShortcuts", default: nil)
}
