/* Window/Services/WindowStorageService.swift — Registered previews and versioned persistence. */
import Defaults
import SwiftUI

@MainActor
final class WindowStorageService {
    private struct Registration {
        weak var window: NSWindow?
        weak var capture: CaptureCoordinator?
    }
    private var previews: [UUID: Registration] = [:]
    private let logger = AppLogger.interface

    func register(_ window: NSWindow, capture: CaptureCoordinator) {
        previews[capture.id] = Registration(window: window, capture: capture)
    }
    func unregister(_ id: UUID) { previews.removeValue(forKey: id) }

    func collectWindows() -> [Window] {
        previews.compactMap { id, entry in
            guard let window = entry.window, let capture = entry.capture else { return nil }
            return Window(
                frame: window.frame,
                id: id,
                sources: capture.sources,
                hideWhenFocused: capture.hideWhenFocused,
                displayIdentifier: window.screen?.persistentIdentifier
            )
        }.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func storeWindows() {
        do { Defaults[.storedWindows] = try JSONEncoder().encode(SavedCollection(collectWindows())) }
        catch { logger.logError(error, context: "Could not save previews") }
    }

    func restoreWindows(using createWindow: (Window) -> Void) {
        guard let data = Defaults[.storedWindows] else { return }
        do {
            let decoded = try SavedCollection<Window>.decode(data)
            if decoded.legacy {
                let encoded = try JSONEncoder().encode(SavedCollection(decoded.items))
                if UserDefaults.standard.data(forKey: "storedWindows.legacyBackup") == nil {
                    UserDefaults.standard.set(data, forKey: "storedWindows.legacyBackup")
                }
                Defaults[.storedWindows] = encoded
            }
            decoded.items.forEach(createWindow)
        } catch {
            // Keep the original bytes for recovery rather than migrating an empty result.
            UserDefaults.standard.set(data, forKey: "storedWindows.unreadableBackup")
            logger.logError(error, context: "Could not restore saved previews; original data preserved")
        }
    }

    func applyWindows(_ windows: [Window], using handler: (Window) -> Void) { windows.forEach(handler) }
}

extension NSScreen {
    var persistentIdentifier: String? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
