/*
 Shortcut/ShortcutItem.swift
 Overview

 Created by William Pierce on 2/16/25.
*/

import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue: String = try container.decode(String.self)
        self.init(rawValue)
    }
}

struct ShortcutItem: Identifiable, Codable, Hashable {
    let id: UUID
    var windowTitles: [String]
    let shortcutName: KeyboardShortcuts.Name

    init(windowTitles: [String], shortcutName: KeyboardShortcuts.Name) {
        self.id = UUID()
        self.windowTitles = windowTitles
        self.shortcutName = shortcutName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(windowTitles)
        hasher.combine(shortcutName)
    }
}
