/*
 Source/Services/SourceAXService.swift
 Overview

 Created by William Pierce on 2/22/25.

 Manages AXUIElement tracking across spaces using a timer-based approach
 and provides persistent storage of window references.
*/

import AppKit
import ApplicationServices
import CoreGraphics

final class SourceAXService {
    // Dependencies
    private let logger = AppLogger.sources

    // Private State
    private var elementCheckTimer: Timer?
    private var knownElements: Set<AXUIElementIdentifier> = []

    // Published State
    private(set) var axElements: [AXUIElement] = []

    init() {
        startElementChecks()
        logger.debug("AXUIElement tracking service initialized")
    }

    deinit {
        elementCheckTimer?.invalidate()
    }

    // MARK: - Public Methods

    @MainActor
    func updateElementsForCurrentSpace() {
        logger.debug("Starting AXUIElement update for current space")
        let currentElements: [AXUIElement] = getCurrentSpaceElements()
        logger.info("Element update complete: total=\(currentElements.count)")
    }

    // MARK: - Element Checks

    private func startElementChecks() {
        elementCheckTimer?.invalidate()
        
        elementCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateElementsForCurrentSpace()
            }
        }
        
        logger.debug("Started periodic element checks")
    }

    // MARK: - Element Management

    private func getCurrentSpaceElements() -> [AXUIElement] {
        var elementMapping: [(element: AXUIElement, windowId: CGWindowID)] = []
        let windowMapping = getWindowMapping()

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if let windows: [AXUIElement] = getApplicationWindows(for: app) {
                for window: AXUIElement in windows {
                    if let (title, windowId) = matchWindowIdentifiers(
                        window: window,
                        pid: app.processIdentifier,
                        windowMapping: windowMapping
                    ) {
                        elementMapping.append((window, windowId))
                        logger.debug(
                            "Matched window: pid=\(app.processIdentifier), title='\(title)'")
                    }
                }
            }
        }

        processNewElements(elementMapping)
        return elementMapping.map { $0.element }
    }

    private func getWindowMapping() -> [String: CGWindowID] {
        let windowListOptions = CGWindowListOption(arrayLiteral: .optionOnScreenOnly)
        guard
            let windowList = CGWindowListCopyWindowInfo(windowListOptions, kCGNullWindowID)
                as? [[CFString: Any]]
        else {
            logger.warning("Failed to retrieve window list")
            return [:]
        }

        return windowList.reduce(into: [:]) { mapping, window in
            guard let windowId = window[kCGWindowNumber] as? CGWindowID,
                let pid = window[kCGWindowOwnerPID] as? pid_t,
                let title = window[kCGWindowName] as? String
            else { return }

            mapping["\(pid):\(title)"] = windowId
        }
    }

    private func getApplicationWindows(for app: NSRunningApplication) -> [AXUIElement]? {
        let appElement: AXUIElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?

        guard
            AXUIElementCopyAttributeValue(
                appElement,
                kAXWindowsAttribute as CFString,
                &windowsRef
            ) == .success
        else { return nil }

        return windowsRef as? [AXUIElement]
    }

    private func matchWindowIdentifiers(
        window: AXUIElement,
        pid: pid_t,
        windowMapping: [String: CGWindowID]
    ) -> (title: String, windowId: CGWindowID)? {
        var titleRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
                == .success,
            let title = titleRef as? String,
            let windowId: CGWindowID = windowMapping["\(pid):\(title)"]
        else { return nil }

        return (title, windowId)
    }

    private func processNewElements(_ elements: [(element: AXUIElement, windowId: CGWindowID)]) {
        var addedCount = 0

        for (element, windowId) in elements {
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)

            let identifier = AXUIElementIdentifier(pid: pid, windowId: windowId)
            if !knownElements.contains(identifier) {
                knownElements.insert(identifier)
                axElements.append(element)
                addedCount += 1
            }
        }

        if addedCount > 0 {
            logger.info("Added \(addedCount) new elements")
        }
    }
}

// MARK: - Support Types

private struct AXUIElementIdentifier: Hashable {
    let pid: pid_t
    let windowId: CGWindowID
}
