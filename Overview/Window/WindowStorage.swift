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
            /// Validate dimensions
            guard width > Constants.Validation.minDimension,
                height > Constants.Validation.minDimension
            else {
                throw WindowStorageError.validationFailed(
                    "Invalid dimensions: \(width)x\(height)"
                )
            }

            /// Validate position
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

    func saveWindowStates() {
        do {
            let states = collectWindowStates()
            try validateWindowStates(states)
            try persistWindowStates(states)
            logger.info("Successfully saved \(states.count) window states")
        } catch {
            logger.logError(error, context: "Failed to save window states")
        }
    }

    func restoreWindows(using createWindow: (NSRect) -> Void) {
        do {
            let states = try loadValidatedStates()

            logger.debug("Beginning window restoration: count=\(states.count)")
            states.forEach { state in
                createWindow(state.frame)
            }

            logger.info("Successfully restored \(states.count) windows")
        } catch {
            logger.logError(error, context: "Window restoration failed")
        }
    }

    func getStoredWindowCount() -> Int {
        do {
            return try loadValidatedStates().count
        } catch {
            logger.debug("Failed to get stored window count: \(error.localizedDescription)")
            return 0
        }
    }

    func validateStoredState() -> Bool {
        do {
            _ = try loadValidatedStates()
            return true
        } catch {
            logger.error("Stored state validation failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private Methods

    private func collectWindowStates() -> [WindowState] {
        NSApplication.shared.windows.compactMap { window in
            guard window.contentView?.ancestorOrSelf(ofType: NSHostingView<PreviewView>.self) != nil
            else {
                return nil
            }
            return WindowState(frame: window.frame)
        }
    }

    private func validateWindowStates(_ states: [WindowState]) throws {
        guard states.count <= Constants.Validation.maxWindowCount else {
            throw WindowStorageError.validationFailed(
                "Too many windows: \(states.count)"
            )
        }

        try states.forEach { state in
            try state.validate()
        }

        logger.debug("Window states validated: count=\(states.count)")
    }

    private func persistWindowStates(_ states: [WindowState]) throws {
        do {
            let data = try JSONEncoder().encode(states)
            defaults.set(data, forKey: Constants.storageKey)
            logger.debug("Window states persisted to storage")
        } catch {
            logger.error("State encoding failed: \(error.localizedDescription)")
            throw WindowStorageError.encodingFailed
        }
    }

    private func loadValidatedStates() throws -> [WindowState] {
        guard let data = defaults.data(forKey: Constants.storageKey) else {
            logger.debug("No stored window states found")
            throw WindowStorageError.noDataFound
        }

        do {
            let states = try JSONDecoder().decode([WindowState].self, from: data)
            try validateWindowStates(states)
            return states
        } catch let error as WindowStorageError {
            throw error
        } catch {
            logger.error("State decoding failed: \(error.localizedDescription)")
            throw WindowStorageError.decodingFailed
        }
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
