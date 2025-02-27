/*
 Permission/PermissionManager.swift
 Overview

 Created by William Pierce on 2/15/25.

 Manages screen recording permission state and coordinates setup when needed.
*/

import CoreGraphics
import ScreenCaptureKit
import SwiftUI

@MainActor
final class PermissionManager: ObservableObject {
    // Dependencies
    private let logger = AppLogger.capture
    private let onboardingCoordinator: OnboardingCoordinator

    // Private State
    private var isRequestingPermission: Bool = false

    // Published State
    @Published private(set) var permissionStatus: PermissionStatus = .unknown {
        didSet {
            if oldValue != permissionStatus {
                logger.info("Permission status changed: \(permissionStatus)")
            }
        }
    }

    init() {
        self.onboardingCoordinator = OnboardingCoordinator()
        self.onboardingCoordinator.onPermissionStatusChanged = { [weak self] hasPermission in
            self?.permissionStatus = hasPermission ? .granted : .denied
        }
        logger.debug("Initializing permission manager")
    }

    // MARK: - Permission Types

    enum PermissionStatus: Equatable {
        case unknown
        case denied
        case granted
    }

    // MARK: - Public Methods

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

        let hasAccess: Bool = CGPreflightScreenCaptureAccess()

        if hasAccess {
            permissionStatus = .granted
        } else {
            try await launchOnboardingFlow()
            updatePermissionStatus()

            if permissionStatus != .granted {
                throw PermissionError.permissionDenied
            }
        }
    }

    func updatePermissionStatus() {
        Task {
            do {
                _ = try await SCShareableContent.current
                permissionStatus = .granted
                logger.info("Screen recording permission granted")
            } catch {
                permissionStatus = .denied
                logger.info(
                    "Screen recording permission still denied: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Methods

    private func launchOnboardingFlow() async throws {
        logger.info("Launching setup flow")
        await onboardingCoordinator.startOnboarding()

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
