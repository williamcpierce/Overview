/*
 Window/Services/WindowObserverService.swift
 Overview

 Created by William Pierce on 12/15/24.
*/

import ScreenCaptureKit

final class WindowObserverService {
    private let logger = AppLogger.windows
    private var focusObservers: [UUID: () async -> Void] = [:]
    private var titleObservers: [UUID: () async -> Void] = [:]
    private var sizeObservers: [UUID: () async -> Void] = [:]
    private var workspaceObserver: NSObjectProtocol?
    private var windowObserver: NSObjectProtocol?
    private var titleCheckTimer: Timer?
    private var sizeCheckTimer: Timer?

    deinit {
        stopObserving()
    }

    func addObserver(
        id: UUID,
        onFocusChanged: @escaping () async -> Void,
        onTitleChanged: @escaping () async -> Void,
        onSizeChanged: @escaping () async -> Void
    ) {
        logger.debug("Adding state observer: \(id)")

        focusObservers[id] = onFocusChanged
        titleObservers[id] = onTitleChanged
        sizeObservers[id] = onSizeChanged

        if focusObservers.count == 1 {
            startObserving()
        }
    }

    func removeObserver(id: UUID) {
        logger.debug("Removing state observer: \(id)")
        focusObservers.removeValue(forKey: id)
        titleObservers.removeValue(forKey: id)
        sizeObservers.removeValue(forKey: id)

        if focusObservers.isEmpty {
            stopObserving()
        }
    }

    private func startObserving() {
        logger.info("Starting window state observation")
        setupWorkspaceObserver()
        setupWindowObserver()
        startTitleChecks()
        startSizeChecks()
    }

    private func stopObserving() {
        logger.info("Stopping window state observation")

        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        titleCheckTimer?.invalidate()
        sizeCheckTimer?.invalidate()
    }

    private func setupWorkspaceObserver() {
        logger.debug("Configuring workspace observer")

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                guard let observers = self?.focusObservers else { return }
                for callback in observers.values {
                    await callback()
                }
            }
        }
    }

    private func setupWindowObserver() {
        logger.debug("Configuring window observer")

        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                guard let observers = self?.focusObservers else { return }
                for callback in observers.values {
                    await callback()
                }
            }
        }
    }

    private func startTitleChecks() {
        titleCheckTimer?.invalidate()
        logger.debug("Starting title check timer")

        titleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            Task { [weak self] in
                guard let observers = self?.titleObservers else { return }
                for callback in observers.values {
                    await callback()
                }
            }
        }
    }
    
    private func startSizeChecks() {
        sizeCheckTimer?.invalidate()
        logger.debug("Starting size check timer")

        sizeCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
            [weak self] _ in
            Task { [weak self] in
                guard let observers = self?.sizeObservers else { return }
                for callback in observers.values {
                    await callback()
                }
            }
        }
    }
}
