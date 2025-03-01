/*
 Layout/Layout.swift
 Overview

 Created by William Pierce on 2/24/25.
*/

import Foundation

struct Layout: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var windows: [WindowState]
    var createdAt: Date
    var updatedAt: Date

    init(name: String, windows: [WindowState]) {
        self.id = UUID()
        self.name = name
        self.windows = windows
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    mutating func update(name: String? = nil, windows: [WindowState]? = nil) {
        if let name = name {
            self.name = name
        }

        if let windows = windows {
            self.windows = windows
        }

        self.updatedAt = Date()
    }
}
