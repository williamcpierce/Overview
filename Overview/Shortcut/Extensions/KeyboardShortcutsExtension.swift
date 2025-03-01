/*
 Shortcut/Extensions/KeyboardShortcutsExtension.swift
 Overview

 Created by William Pierce on 2/16/25.

 Defines custom keyboard shortcut names for the KeyboardShortcuts package.
*/

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let focusSelectedWindow = Self("focusSelectedWindow")
}

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
