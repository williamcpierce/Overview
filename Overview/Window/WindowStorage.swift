/*
 Window/WindowStorage.swift
 Overview

 Created by William Pierce on 1/5/25.

 Manages persistence and restoration of window state information.
*/

import AppKit
import SwiftUI

final class WindowStorage {
    // Constants
    private struct Constants {
        static let storageKey: String = "StoredWindowPositions"

        struct Validation {
            static let maxPosition: Double = 10000
            static let minDimension: Double = 0
            static let maxWindowCount: Int = 20
        }
    }

    // Dependencies
    private let logger = AppLogger.interface
    private let defaults: UserDefaults

    // Singleton
    static let shared = WindowStorage()

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        logger.debug("Window storage initialized")
    }

    // MARK: - Window State

    struct WindowState: Codable, Equatable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double

        var frame: NSRect {
            NSRect(x: x, y: y, width: width, height: height)
        }

        init(frame: NSRect) {
            self.x = frame.origin.x
            self.y = frame.origin.y
            self.width = frame.width
            self.height = frame.height
        }

        func validate() throws {
            guard width > Constants.Validation.minDimension,
                height > Constants.Validation.minDimension
            else {
                throw WindowStorageError.validationFailed(
                    "Invalid dimensions: \(width)x\(height)"
                )
            }

            guard abs(x) <= Constants.Validation.maxPosition,
                abs(y) <= Constants.Validation.maxPosition
            else {
                throw WindowStorageError.validationFailed(
                    "Invalid position: (\(x), \(y))"
                )
            }
        }
    }

    // MARK: - Public Methods

    func storeWindows() {
        do {
            let windows = collectWindows()
            try validateWindows(windows)
            try saveWindows(windows)
            logger.info("Successfully saved \(windows.count) windows")
        } catch {
            logger.logError(error, context: "Failed to save windows")
        }
    }

    func collectWindows() -> [WindowState] {
        NSApplication.shared.windows.compactMap { window in
            guard window.contentView?.ancestorOrSelf(ofType: NSHostingView<PreviewView>.self) != nil
            else {
                return nil
            }
            return WindowState(frame: window.frame)
        }
    }

    func restoreWindows(using createWindow: (NSRect) -> Void) {
        do {
            let windows = try loadWindows()

            logger.debug("Beginning window restoration: count=\(windows.count)")
            windows.forEach { window in
                createWindow(window.frame)
            }

            logger.info("Successfully restored \(windows.count) windows")
        } catch {
            logger.logError(error, context: "Window restoration failed")
        }
    }

    func applyWindows(_ windows: [WindowState], using handler: (NSRect) -> Void) {
        do {
            try validateWindows(windows)

            logger.debug("Beginning window application: count=\(windows.count)")
            windows.forEach { window in
                handler(window.frame)
            }

            logger.info("Successfully applied \(windows.count) windows")
        } catch {
            logger.logError(error, context: "Window application failed")
        }
    }

    // MARK: - Private Methods

    private func saveWindows(_ windows: [WindowState]) throws {
        do {
            let data = try JSONEncoder().encode(windows)
            defaults.set(data, forKey: Constants.storageKey)
            logger.debug("Windows persisted to storage")
        } catch {
            logger.error("Window state encoding failed: \(error.localizedDescription)")
            throw WindowStorageError.encodingFailed
        }
    }

    private func loadWindows() throws -> [WindowState] {
        guard let data = defaults.data(forKey: Constants.storageKey) else {
            logger.debug("No stored windows found")
            throw WindowStorageError.noDataFound
        }

        do {
            let windows = try JSONDecoder().decode([WindowState].self, from: data)
            try validateWindows(windows)
            return windows
        } catch let error as WindowStorageError {
            throw error
        } catch {
            logger.error("Window state decoding failed: \(error.localizedDescription)")
            throw WindowStorageError.decodingFailed
        }
    }

    private func validateWindows(_ windows: [WindowState]) throws {
        guard windows.count <= Constants.Validation.maxWindowCount else {
            throw WindowStorageError.validationFailed(
                "Too many windows: \(windows.count)"
            )
        }

        try windows.forEach { window in
            try window.validate()
        }

        logger.debug("Windows validated: count=\(windows.count)")
    }
}

// MARK: - Window Storage Error

enum WindowStorageError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case validationFailed(String)
    case noDataFound

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode window states"
        case .decodingFailed:
            return "Failed to decode stored window states"
        case .validationFailed(let reason):
            return "Window state validation failed: \(reason)"
        case .noDataFound:
            return "No stored window data found"
        }
    }
}
