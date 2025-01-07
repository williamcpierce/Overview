/*
 Window/WindowStorage.swift
 Overview

 Created by William Pierce on 1/5/25.

 Manages persistence and restoration of window state information.
*/

import AppKit
import SwiftUI

final class WindowStorage {
    private let logger = AppLogger.interface
    private let windowPositionsKey = "StoredWindowPositions"
    static let shared: WindowStorage = WindowStorage()

    struct WindowState: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    func saveWindowStates() {
        var positions: [WindowState] = []

        NSApplication.shared.windows.forEach { window in
            if window.contentView?.ancestorOrSelf(ofType: NSHostingView<ContentView>.self) != nil {
                positions.append(
                    WindowState(
                        x: window.frame.origin.x,
                        y: window.frame.origin.y,
                        width: window.frame.width,
                        height: window.frame.height
                    ))
            }
        }

        do {
            let data = try JSONEncoder().encode(positions)
            UserDefaults.standard.set(data, forKey: windowPositionsKey)
            logger.info("Saved \(positions.count) window positions")
        } catch {
            logger.logError(error, context: "Failed to save window positions")
        }
    }

    func restoreWindows(using createWindow: (NSRect) -> Void) {
        guard let data = UserDefaults.standard.data(forKey: windowPositionsKey) else { return }

        do {
            let positions = try JSONDecoder().decode([WindowState].self, from: data)
            positions.forEach { position in
                createWindow(
                    NSRect(
                        x: position.x,
                        y: position.y,
                        width: position.width,
                        height: position.height
                    ))
            }
            logger.info("Restored \(positions.count) windows")
        } catch {
            logger.logError(error, context: "Failed to restore window positions")
        }
    }

    func getStoredWindowCount() -> Int {
        guard let data: Data = UserDefaults.standard.data(forKey: windowPositionsKey) else {
            return 0
        }

        do {
            let positions: [WindowStorage.WindowState] = try JSONDecoder().decode(
                [WindowState].self, from: data)
            return positions.count
        } catch {
            logger.error("Failed to decode stored window count: \(error.localizedDescription)")
            return 0
        }
    }

    func validateStoredState() -> Bool {
        guard let data: Data = UserDefaults.standard.data(forKey: windowPositionsKey) else {
            return true
        }

        do {
            let positions: [WindowStorage.WindowState] = try JSONDecoder().decode(
                [WindowState].self, from: data)

            // Validate each stored window position
            for position: WindowStorage.WindowState in positions {
                // Check for invalid dimensions
                if position.width <= 0 || position.height <= 0 {
                    logger.error(
                        "Invalid stored window dimensions: \(position.width)x\(position.height)")
                    return false
                }

                // Check for extreme positions that might indicate corruption
                if abs(position.x) > 10000 || abs(position.y) > 10000 {
                    logger.error(
                        "Suspicious window position detected: (\(position.x), \(position.y))")
                    return false
                }
            }

            return true
        } catch {
            logger.error("Failed to validate stored window state: \(error.localizedDescription)")
            return false
        }
    }
}

extension NSView {
    func ancestorOrSelf<T>(ofType type: T.Type) -> T? {
        if let self = self as? T {
            return self
        }
        return superview?.ancestorOrSelf(ofType: type)
    }
}
