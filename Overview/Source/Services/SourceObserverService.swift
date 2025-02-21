/*
 Source/Services/SourceObserverService.swift
 Overview

 Created by William Pierce on 12/15/24.

 Provides source window state observation and notification management.
*/

import Cocoa
import ScreenCaptureKit

final class SourceObserverService {
    // Dependencies
    private let logger = AppLogger.sources

    // Private State
    private var focusObservers: [UUID: () async -> Void] = [:]
    private var titleObservers: [UUID: () async -> Void] = [:]
    private var workspaceObserver: NSObjectProtocol?
    private var windowObserver: NSObjectProtocol?
    private var appObserver: NSObjectProtocol?

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

        // Start observing only when first observer is added
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
        logger.info("Starting source window state observation")

        // Observe application focus changes
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.triggerFocusObservers()
        }

        // Observe window focus changes
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.triggerFocusObservers()
        }

        // Observe window focus loss
        workspaceObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.triggerFocusObservers()
        }
    }

    private func stopObserving() {
        logger.info("Stopping source window state observation")

        if let observer = appObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = workspaceObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func triggerFocusObservers() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Immediately trigger all focus observers
            for callback in self.focusObservers.values {
                await callback()
            }
        }
    }
}
