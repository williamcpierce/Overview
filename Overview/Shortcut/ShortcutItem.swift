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
        let rawValue = try container.decode(String.self)
        self.init(rawValue)
    }
}

struct ShortcutItem: Codable, Identifiable, Equatable {
    let id: UUID
    var windowTitle: String
    var shortcutName: KeyboardShortcuts.Name

    init(id: UUID = UUID(), windowTitle: String, shortcutName: KeyboardShortcuts.Name) {
        self.id = id
        self.windowTitle = windowTitle
        self.shortcutName = shortcutName
    }
}
