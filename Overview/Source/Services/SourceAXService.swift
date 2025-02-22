/*
 Source/Services/SourceAXService.swift
 Overview

 Created by William Pierce on 2/22/25.

 Manages AXUIElement tracking across spaces and provides persistent storage
 of window references.
*/

import AppKit
import ApplicationServices
import CoreGraphics

final class SourceAXService {
    // Dependencies
    private let logger = AppLogger.sources

    // Private State
    private var spaceChangeObserver: NSObjectProtocol?
    private var knownElements: Set<AXUIElementIdentifier> = []

    // Published State
    private(set) var axElements: [AXUIElement] = []

    init() {
        setupSpaceObserver()
        logger.debug("AXUIElement tracking service initialized")
    }

    deinit {
        if let observer = spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Space Change Tracking

    private func setupSpaceObserver() {
        spaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSpaceChange()
        }

        logger.info("Space change observer configured")
    }

    private func handleSpaceChange() {
        logger.debug("Active space changed, updating AXUIElement collection")
        Task { @MainActor in
            updateElementsForCurrentSpace()
        }
    }

    // MARK: - Element Management

    @MainActor
    func updateElementsForCurrentSpace() {
        logger.info("Updating AXUIElements for current space")
        let currentElements = getCurrentSpaceElements()
        logger.debug("Found \(currentElements.count) elements in current space")
        //        processNewElements(currentElements)
        logger.info("Total persisted elements: \(axElements.count)")
    }

    // In SourceAXService.swift
    private func getCurrentSpaceElements() -> [AXUIElement] {
        var elementMapping: [(element: AXUIElement, windowId: CGWindowID)] = []

        // Get all window info first
        let windowListOptions = CGWindowListOption(arrayLiteral: .optionOnScreenOnly)
        guard
            let windowList = CGWindowListCopyWindowInfo(windowListOptions, kCGNullWindowID)
                as? [[CFString: Any]]
        else {
            logger.warning("Failed to get window list")
            return []
        }

        // Create a mapping of pid+title to window ID
        var windowMapping: [String: CGWindowID] = [:]
        for window in windowList {
            guard let windowId = window[kCGWindowNumber] as? CGWindowID,
                let pid = window[kCGWindowOwnerPID] as? pid_t,
                let title = window[kCGWindowName] as? String
            else { continue }

            let key = "\(pid):\(title)"
            windowMapping[key] = windowId
            logger.debug(
                "Found window in CGWindowList: pid=\(pid), title='\(title)', windowId=\(windowId)")
        }

        let apps = NSWorkspace.shared.runningApplications
        logger.debug("Scanning \(apps.count) running applications")

        for app in apps {
            guard app.activationPolicy == .regular else { continue }

            let pid = app.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                appElement,
                kAXWindowsAttribute as CFString,
                &windowsRef
            )

            if result == .success,
                let windows = windowsRef as? [AXUIElement]
            {
                // For each AX window, get its title and find matching CGWindowID
                for window in windows {
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(
                        window, kAXTitleAttribute as CFString, &titleRef) == .success,
                        let title = titleRef as? String
                    {
                        let key = "\(pid):\(title)"
                        if let windowId = windowMapping[key] {
                            elementMapping.append((window, windowId))
                            logger.debug(
                                "Matched AXUIElement with window: pid=\(pid), title='\(title)', windowId=\(windowId)"
                            )
                        }
                    }
                }

                logger.debug(
                    "Found \(windows.count) windows for app: \(app.localizedName ?? "unknown") (pid: \(pid))"
                )
            }
        }

        // Process the elements we found with their known window IDs
        processNewElements(elementMapping)

        return elementMapping.map { $0.element }
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
                logger.debug("Added new AXUIElement: pid=\(pid), windowId=\(windowId)")
            } else {
                logger.debug("Skipping duplicate element: pid=\(pid), windowId=\(windowId)")
            }
        }

        logger.info("Added \(addedCount) new elements in this update")
        logger.debug(
            "Current elements: \(knownElements.map { "pid=\($0.pid), windowId=\($0.windowId)" }.joined(separator: ", "))"
        )
    }

    private struct AXUIElementIdentifier: Hashable {
        let pid: pid_t
        let windowId: CGWindowID
    }
}
