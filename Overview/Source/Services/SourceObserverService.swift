//
// Source/Services/SourceMonitorService.swift
//
// Created by [Your Name], [Date].
//
// Manages AXUIElement tracking, observes window focus changes and
// (optionally) window title updates via AXObservers or a simple timer.
//

import AppKit
import ApplicationServices

final class SourceObserverService {
    // Dependencies
    private let logger = AppLogger.sources
    
    // MARK: - State
    private var knownElements: Set<AXUIElementIdentifier> = []
    private(set) var axElements: [AXUIElement] = []
    
    // Observers
    private var focusObservers: [UUID: () async -> Void] = [:]
    private var titleObservers: [UUID: () async -> Void] = [:]
    
    // Optional single fallback Timer
    private var refreshTimer: Timer?

    // MARK: - Init/Deinit
    init() {
        logger.debug("SourceMonitorService initialized")
        startObservingFocusNotifications()
        // Optionally start a single fallback timer if you truly need periodic scanning
         startFallbackTimer()
    }
    
    deinit {
        stopObservingFocusNotifications()
        refreshTimer?.invalidate()
    }

    // MARK: - Public Observers
    func addObserver(
        id: UUID,
        onFocusChanged: @escaping () async -> Void,
        onTitleChanged: @escaping () async -> Void
    ) {
        focusObservers[id] = onFocusChanged
        titleObservers[id] = onTitleChanged
    }
    
    func removeObserver(id: UUID) {
        focusObservers.removeValue(forKey: id)
        titleObservers.removeValue(forKey: id)
    }

    // MARK: - Focus Observations via NSWorkspace
    private func startObservingFocusNotifications() {
        // Application activated
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notifyFocusObservers()
        }

        // Window focus gain
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notifyFocusObservers()
        }

        // Window focus loss
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notifyFocusObservers()
        }

        logger.debug("Focus notifications setup complete")
    }

    private func stopObservingFocusNotifications() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    private func notifyFocusObservers() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            for callback in self.focusObservers.values {
                await callback()
            }
        }
    }

    // MARK: - Title Observations
    /// If you prefer an event-driven approach with AXObservers:
    ///  - You’d create AXObservers for each AXUIElement and handle kAXTitleChangedNotification.
    ///  - Otherwise, you can do a fallback check if you prefer a periodic approach.

    func pollTitleChanges() {
        // If you're not using AXObserver notifications, you can manually check
        // known AXUIElements or you can keep your old “captureServices.getAvailableSources()” approach
        Task { @MainActor in
            for callback in self.titleObservers.values {
                await callback()
            }
        }
    }

    // MARK: - AXUIElement Tracking
    /// For discovering new windows, you can do a manual check or call it from a single timer
    func updateElementsForCurrentSpace() {
        logger.debug("Updating AXUIElements for current space")
        let foundElements = getCurrentSpaceElements()
        logger.info("Element update complete: total = \(foundElements.count)")
    }

    private func getCurrentSpaceElements() -> [AXUIElement] {
        var elementMapping: [(element: AXUIElement, windowId: CGWindowID)] = []
        let windowMapping = getWindowMapping()

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let windows = getApplicationWindows(for: app) else { continue }
            for window in windows {
                if let (title, windowId) = matchWindowIdentifiers(
                    window: window,
                    pid: app.processIdentifier,
                    windowMapping: windowMapping
                ) {
                    elementMapping.append((window, windowId))
                    logger.debug("Matched window: pid=\(app.processIdentifier), title='\(title)'")
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
            guard
                let windowId = window[kCGWindowNumber] as? CGWindowID,
                let pid = window[kCGWindowOwnerPID] as? pid_t,
                let title = window[kCGWindowName] as? String
            else { return }

            mapping["\(pid):\(title)"] = windowId
        }
    }

    private func getApplicationWindows(for app: NSRunningApplication) -> [AXUIElement]? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
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
            let windowId = windowMapping["\(pid):\(title)"]
        else {
            return nil
        }

        return (title, windowId)
    }

    private func processNewElements(_ elements: [(AXUIElement, CGWindowID)]) {
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

    // MARK: - (Optional) Single Timer
    private func startFallbackTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElementsForCurrentSpace()
                self?.notifyFocusObservers()
                self?.pollTitleChanges()
            }
        }
        logger.debug("Fallback timer started")
    }
}

// Supporting type
private struct AXUIElementIdentifier: Hashable {
    let pid: pid_t
    let windowId: CGWindowID
}
