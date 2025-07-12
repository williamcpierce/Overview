/*
 Shortcut/Shortcut.swift
 Overview

 Created by William Pierce on 2/16/25.
*/

import Foundation
import KeyboardShortcuts

struct Shortcut: Identifiable, Codable, Hashable {
    let id: UUID
    var windowTitles: [String]
    let shortcutName: KeyboardShortcuts.Name
    var isEnabled: Bool = true

    init(
        windowTitles: [String], shortcutName: KeyboardShortcuts.Name,
        isEnabled: Bool = true
    ) {
        self.id = UUID()
        self.windowTitles = windowTitles
        self.shortcutName = shortcutName
        self.isEnabled = isEnabled
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(windowTitles)
        hasher.combine(shortcutName)
        hasher.combine(isEnabled)
    }
}
