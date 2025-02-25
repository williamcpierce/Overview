/*
 Window/Services/WindowStorageService.swift
 Overview

 Created by William Pierce on 1/5/25.

 Manages persistence and restoration of window state information.
*/

import AppKit
import SwiftUI

final class WindowStorageService {
    // Dependencies
    private let logger = AppLogger.interface

    // MARK: - Public Methods

    func storeWindows(_ windowStates: [WindowState]? = nil) {
        do {
            let windows = windowStates ?? collectWindows()
            try saveWindows(windows)
            logger.info("Successfully saved \(windows.count) windows")
        } catch {
            logger.logError(error, context: "Failed to save windows")
        }
    }

    func collectWindows(titleProvider: ((NSWindow) -> String?)? = nil) -> [WindowState] {
        NSApplication.shared.windows.compactMap { window in
            guard window.contentView?.ancestorOrSelf(ofType: NSHostingView<PreviewView>.self) != nil
            else {
                return nil
            }
            
            let boundWindowTitle = titleProvider?(window)
            return WindowState(frame: window.frame, boundWindowTitle: boundWindowTitle)
        }
    }

    func restoreWindows(using handler: (NSRect, String?) -> Void) {
        do {
            let windows = try loadWindows()
            windows.forEach { window in
                handler(window.frame, window.boundWindowTitle)
            }
            logger.info("Successfully restored \(windows.count) windows")
        } catch {
            logger.logError(error, context: "Window restoration failed")
        }
    }

    func applyWindows(_ windows: [WindowState], using handler: (NSRect) -> Void) {
        windows.forEach { window in
            handler(window.frame)
        }
        logger.info("Successfully applied \(windows.count) windows")
    }

    // MARK: - Private Methods

    private func saveWindows(_ windows: [WindowState]) throws {
        do {
            let data = try JSONEncoder().encode(windows)
            UserDefaults.standard.set(data, forKey: WindowSettingsKeys.storedWindows)
            logger.debug("Windows persisted to storage")
        } catch {
            logger.error("Window state encoding failed: \(error.localizedDescription)")
            throw WindowStorageError.encodingFailed
        }
    }

    func loadWindows() throws -> [WindowState] {
        guard let data = UserDefaults.standard.data(forKey: WindowSettingsKeys.storedWindows) else {
            logger.debug("No stored windows found")
            throw WindowStorageError.noDataFound
        }

        do {
            let windows = try JSONDecoder().decode([WindowState].self, from: data)
            return windows
        } catch let error as WindowStorageError {
            throw error
        } catch {
            logger.error("Window state decoding failed: \(error.localizedDescription)")
            throw WindowStorageError.decodingFailed
        }
    }
}

// MARK: - Window Storage Error

enum WindowStorageError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case noDataFound

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode window states"
        case .decodingFailed:
            return "Failed to decode stored window states"
        case .noDataFound:
            return "No stored window data found"
        }
    }
}
