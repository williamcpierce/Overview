/*
 Layout/LayoutManager.swift
 Overview

 Created by William Pierce on 2/24/25.

 Manages window layout storage, retrieval, and application.
*/

import Defaults
import SwiftUI

@MainActor
final class LayoutManager: ObservableObject {
    // Dependencies
    private let windowServices: WindowServices = WindowServices.shared
    private let logger = AppLogger.interface

    // Published State
    @Published var layouts: [Layout] = [] {
        didSet {
            saveLayouts()
        }
    }

    // Layout Settings
    private var launchLayoutUUID: UUID? = Defaults[.launchLayoutUUID]

    init() {
        self.layouts = loadLayouts()
        logger.debug("Layout manager initialized with \(layouts.count) layouts")
    }

    // MARK: - Public Methods

    func createLayout(name: String) -> Layout? {
        guard isLayoutNameUnique(name) else {
            logger.warning("Attempted to create layout with non-unique name: \(name)")
            return nil
        }

        let currentWindows = windowServices.windowStorage.collectWindows()
        let layout = Layout(name: name, windows: currentWindows)

        layouts.append(layout)

        logger.info("Created new layout '\(name)' with \(currentWindows.count) windows")
        return layout
    }

    func updateLayout(id: UUID, name: String? = nil) {
        guard let index = layouts.firstIndex(where: { $0.id == id }) else {
            logger.warning("Attempted to update non-existent layout: \(id)")
            return
        }

        var layout = layouts[index]

        if let name = name {
            guard isLayoutNameUnique(name, excludingId: id) else {
                logger.warning("Attempted to update layout with non-unique name: \(name)")
                return
            }
            layout.update(name: name)
        } else {
            let currentWindows = windowServices.windowStorage.collectWindows()
            layout.update(windows: currentWindows)
            logger.info("Updated layout '\(layout.name)' with \(currentWindows.count) windows")
        }

        layouts[index] = layout
    }

    func deleteLayout(id: UUID) {
        guard layouts.contains(where: { $0.id == id }) else {
            logger.warning("Attempted to delete non-existent layout: \(id)")
            return
        }

        let layoutName = layouts.first(where: { $0.id == id })?.name ?? "Unknown"
        layouts.removeAll(where: { $0.id == id })

        if launchLayoutUUID == id {
            launchLayoutUUID = nil
        }

        logger.info("Deleted layout '\(layoutName)'")
    }

    func getLaunchLayout() -> Layout? {
        guard let uuid = launchLayoutUUID else {
            return nil
        }
        return layouts.first(where: { $0.id == uuid })
    }

    func applyLayout(_ layout: Layout, using handler: (WindowState) -> Void) {
        logger.info("Applying layout '\(layout.name)' with \(layout.windows.count) windows")
        layout.windows.forEach { windowState in
            handler(windowState)
        }
    }

    func shouldApplyLayoutOnLaunch() -> Bool {
        return getLaunchLayout() != nil
    }

    func isLayoutNameUnique(_ name: String, excludingId: UUID? = nil) -> Bool {
        return layouts.allSatisfy {
            !($0.name.lowercased() == name.lowercased() && $0.id != excludingId)
        }
    }

    // MARK: - Private Methods

    private func saveLayouts() {
        do {
            let encodedLayouts = try JSONEncoder().encode(layouts)
            Defaults[.layouts] = encodedLayouts
            logger.debug("Saved \(layouts.count) layouts to user defaults")
        } catch {
            logger.logError(error, context: "Failed to encode layouts")
        }
    }

    private func loadLayouts() -> [Layout] {
        guard let data = Defaults[.layouts] else {
            logger.debug("No saved layouts found")
            return []
        }

        do {
            let decodedLayouts = try JSONDecoder().decode([Layout].self, from: data)
            logger.info("Loaded \(decodedLayouts.count) layouts")
            return decodedLayouts
        } catch {
            logger.logError(error, context: "Failed to decode layouts")
            return []
        }
    }
}
