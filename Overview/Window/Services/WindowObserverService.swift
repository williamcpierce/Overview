/*
 Window/Services/WindowObserverService.swift
 Overview

 Created by William Pierce on 12/15/24.

 Provides window state observation and notification management.
*/

import ScreenCaptureKit

/// Manages window state observation and notification distribution for
/// window focus and title changes.
final class WindowObserverService {
    private let logger = AppLogger.windows

    // MARK: - Private State

    private var focusObservers: [UUID: () async -> Void] = [:]
    private var titleCheckTimer: Timer?
    private var titleObservers: [UUID: () async -> Void] = [:]
    private var windowObserver: NSObjectProtocol?
    private var workspaceObserver: NSObjectProtocol?

    deinit {
        stopObserving()
    }

    // MARK: - Public Methods

    func addObserver(
        id: UUID,
        onFocusChanged: @escaping () async -> Void,
        onTitleChanged: @escaping () async -> Void
    ) {
        logger.debug("Adding state observer: \(id)")

        focusObservers[id] = onFocusChanged
        titleObservers[id] = onTitleChanged

        if focusObservers.count == 1 {
            startObserving()
        }
    }

    func removeObserver(id: UUID) {
        logger.debug("Removing state observer: \(id)")
        focusObservers.removeValue(forKey: id)
        titleObservers.removeValue(forKey: id)

        if focusObservers.isEmpty {
            stopObserving()
        }
    }

    // MARK: - Private Methods

    private func startObserving() {
        logger.info("Starting window state observation")
        setupWorkspaceObserver()
        setupWindowObserver()
        startTitleChecks()
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
}
