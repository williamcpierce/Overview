/*
 Window/Layout/Layout.swift
 Overview

 Created by William Pierce on 2/24/25.

 Defines data structures for window arrangement layouts.
*/

import Foundation

struct Layout: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var windows: [WindowStorage.WindowState]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, windows: [WindowStorage.WindowState]) {
        self.id = id
        self.name = name
        self.windows = windows
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    mutating func update(name: String? = nil, windows: [WindowStorage.WindowState]? = nil) {
        if let name = name {
            self.name = name
        }

        if let windows = windows {
            self.windows = windows
        }

        self.updatedAt = Date()
    }
}

enum LayoutSettingsKeys {
    static let layouts: String = "storedLayouts"
    static let launchLayoutId: String = "launchLayoutId"
    static let applyLayoutOnLaunch: String = "applyLayoutOnLaunch"

    static let defaults = Defaults()

    struct Defaults {
        let applyLayoutOnLaunch: Bool = false
    }
}
