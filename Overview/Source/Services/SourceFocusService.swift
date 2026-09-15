/* Source/Services/SourceFocusService.swift — Conservative public Accessibility window matching. */
import ApplicationServices
import AppKit
import ScreenCaptureKit

@MainActor
final class SourceFocusService {
    enum FocusResult { case exactWindow, application, unavailable }
    var accessibilityEnabled: Bool { AXIsProcessTrusted() }

    func requestAccessibility() {
        // The documented key value avoids importing the mutable Objective-C global into actor-isolated code.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func focusSource(source: SCWindow) -> FocusResult {
        guard let pid = source.owningApplication?.processID,
              let app = NSRunningApplication(processIdentifier: pid) else { return .unavailable }
        let activated = app.activate()
        if accessibilityEnabled, let title = source.title,
           let window = uniqueWindow(pid: pid, title: title) {
            _ = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            let raised = AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success
            _ = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            if activated && raised { return .exactWindow }
        }
        return activated ? .application : .unavailable
    }

    func focusedTitle(pid: pid_t) -> String? {
        guard accessibilityEnabled else { return nil }
        let app = AXUIElementCreateApplication(pid)
        guard let raw = attribute(app, kAXFocusedWindowAttribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        let window = unsafeDowncast(raw as AnyObject, to: AXUIElement.self)
        return attribute(window, kAXTitleAttribute) as? String
    }

    private func uniqueWindow(pid: pid_t, title: String) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        guard let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] else { return nil }
        let matches = windows.filter { attribute($0, kAXTitleAttribute) as? String == title }
        return matches.count == 1 ? matches[0] : nil
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }
}
