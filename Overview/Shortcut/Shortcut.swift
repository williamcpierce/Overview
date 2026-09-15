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

    private enum CodingKeys: String, CodingKey {
        case id, windowTitles, shortcutName, isEnabled
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        windowTitles = try values.decode([String].self, forKey: .windowTitles)
        shortcutName = KeyboardShortcuts.Name(try values.decode(String.self, forKey: .shortcutName))
        isEnabled = try values.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(windowTitles, forKey: .windowTitles)
        try values.encode(shortcutName.rawValue, forKey: .shortcutName)
        try values.encode(isEnabled, forKey: .isEnabled)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(windowTitles)
        hasher.combine(shortcutName)
        hasher.combine(isEnabled)
    }
}
