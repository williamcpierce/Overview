/*
 Layout/LayoutManager.swift
 Overview

 Created by William Pierce on 2/24/25.

 Manages window layout layout storage, retrieval, and application.
*/

import SwiftUI

@MainActor
final class LayoutManager: ObservableObject {
    // Dependencies
    private let windowStorage: WindowStorage
    private let logger = AppLogger.interface
    private let defaults: UserDefaults

    // Published State
    @Published var layouts: [Layout] = []
    @Published var launchLayoutId: UUID? = nil

    init(
        windowStorage: WindowStorage = WindowStorage.shared,
        defaults: UserDefaults = .standard
    ) {
        self.windowStorage = windowStorage
        self.defaults = defaults

        self.layouts = loadLayouts()

        if let launchLayoutIdString = defaults.string(forKey: LayoutSettingsKeys.launchLayoutId),
            let launchLayoutId = UUID(uuidString: launchLayoutIdString)
        {
            self.launchLayoutId = launchLayoutId
        }

        logger.debug("Layout manager initialized with \(layouts.count) layouts")
    }

    // MARK: - Layout Management

    func createLayout(name: String) -> Layout {
        let currentWindows = windowStorage.collectWindows()
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
            layout.update(name: name)
        } else {
            let currentWindows = windowStorage.collectWindows()
            layout.update(windows: currentWindows)
            logger.info(
                "Updated layout '\(layout.name)' with \(currentWindows.count) windows")
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

        if launchLayoutId == id {
            launchLayoutId = nil
            defaults.removeObject(forKey: LayoutSettingsKeys.launchLayoutId)
        }

        saveLayouts()
        logger.info("Deleted layout '\(layoutName)'")
    }

    func setLaunchLayout(id: UUID?) {
        launchLayoutId = id

        if let id = id {
            defaults.set(id.uuidString, forKey: LayoutSettingsKeys.launchLayoutId)
            logger.info("Set launch layout: \(id)")
        } else {
            defaults.removeObject(forKey: LayoutSettingsKeys.launchLayoutId)
            logger.info("Cleared launch layout")
        }
    }

    func getLaunchLayout() -> Layout? {
        guard let launchLayoutId = launchLayoutId else {
            return nil
        }

        return layouts.first(where: { $0.id == launchLayoutId })
    }

    func applyLayout(_ layout: Layout, using handler: (WindowStorage.WindowState) -> Void) {
        logger.info("Applying layout '\(layout.name)' with \(layout.windows.count) windows")

        layout.windows.forEach { windowState in
            handler(windowState)
        }
    }

    func shouldApplyLayoutOnLaunch() -> Bool {
        return launchLayoutId != nil && getLaunchLayout() != nil
    }

    // MARK: - Private Storage Methods

    private func saveLayouts() {
        do {
            let encodedLayouts = try JSONEncoder().encode(layouts)
            defaults.set(encodedLayouts, forKey: LayoutSettingsKeys.layouts)
            logger.debug("Saved \(layouts.count) layouts to user defaults")
        } catch {
            logger.logError(error, context: "Failed to encode layouts")
        }
    }

    private func loadLayouts() -> [Layout] {
        guard let data = defaults.data(forKey: LayoutSettingsKeys.layouts) else {
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
