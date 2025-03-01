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
    @Published var layouts: [Layout] = []
    @Published var launchLayoutUUID: UUID? = nil

    // Layout Settings
    private var launchLayoutId = Defaults[.launchLayoutId]

    init() {
        self.layouts = loadLayouts()

        if let launchLayoutIdString = launchLayoutId,
            let launchLayoutId = UUID(uuidString: launchLayoutIdString)
        {
            self.launchLayoutUUID = launchLayoutId
        }

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
        saveLayouts()

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
        saveLayouts()
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
            launchLayoutId = nil
        }

        saveLayouts()
        logger.info("Deleted layout '\(layoutName)'")
    }

    func setLaunchLayout(id: UUID?) {
        launchLayoutUUID = id

        if let id = id {
            launchLayoutId = id.uuidString
            logger.info("Set launch layout: \(id)")
        } else {
            launchLayoutId = nil
            logger.info("Cleared launch layout")
        }
    }

    func getLaunchLayout() -> Layout? {
        guard let launchLayoutId = launchLayoutUUID else {
            return nil
        }

        return layouts.first(where: { $0.id == launchLayoutId })
    }

    func applyLayout(_ layout: Layout, using handler: (WindowState) -> Void) {
        logger.info("Applying layout '\(layout.name)' with \(layout.windows.count) windows")

        layout.windows.forEach { windowState in
            handler(windowState)
        }
    }

    func shouldApplyLayoutOnLaunch() -> Bool {
        return launchLayoutUUID != nil && getLaunchLayout() != nil
    }

    func isLayoutNameUnique(_ name: String, excludingId: UUID? = nil) -> Bool {
        return layouts.filter {
            $0.name.lowercased() == name.lowercased() && $0.id != excludingId
        }.isEmpty
    }

    func saveLayouts() {
        do {
            let encodedLayouts = try JSONEncoder().encode(layouts)
            Defaults[.layouts] = encodedLayouts
            logger.debug("Saved \(layouts.count) layouts to user defaults")
        } catch {
            logger.logError(error, context: "Failed to encode layouts")
        }
    }

    // MARK: - Private Methods

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
