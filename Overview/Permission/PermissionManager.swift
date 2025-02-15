/*
 Permission/PermissionManager.swift
 Overview

 Created by William Pierce on 2/15/25.

 Manages screen recording permission state and coordinates setup when needed.
*/

import CoreGraphics
import SwiftUI

@MainActor
final class PermissionManager: ObservableObject {
    // Published State
    @Published private(set) var permissionStatus: PermissionStatus = .unknown {
        didSet {
            if oldValue != permissionStatus {
                logger.info("Permission status changed: \(permissionStatus)")
            }
        }
    }

    // Dependencies
    private let logger = AppLogger.capture
    private let setupCoordinator: SetupCoordinator

    // Private State
    private var isRequestingPermission: Bool = false

    init() {
        self.setupCoordinator = SetupCoordinator()
        logger.debug("Initializing permission manager")
        updatePermissionStatus()
    }

    // MARK: - Permission Status

    enum PermissionStatus: Equatable {
        case unknown
        case denied
        case granted
    }

    func ensurePermission() async throws {
        if permissionStatus == .granted {
            return
        }

        guard !isRequestingPermission else {
            logger.debug("Permission check already in progress")
            return
        }

        isRequestingPermission = true
        defer { isRequestingPermission = false }

        updatePermissionStatus()

        if permissionStatus == .denied {
            try await launchSetupFlow()
            updatePermissionStatus()

            if permissionStatus != .granted {
                throw PermissionError.permissionDenied
            }
        }
    }

    func updatePermissionStatus() {
        let hasAccess = CGPreflightScreenCaptureAccess()
        permissionStatus = hasAccess ? .granted : .denied
    }

    private func launchSetupFlow() async throws {
        logger.info("Launching setup flow")
        await setupCoordinator.startSetupIfNeeded()

        try? await Task.sleep(nanoseconds: 500_000_000)
        updatePermissionStatus()
    }
}

// MARK: - Permission Error

enum PermissionError: LocalizedError {
    case permissionDenied
    case setupIncomplete

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission was denied"
        case .setupIncomplete:
            return "Setup process was not completed"
        }
    }
}
