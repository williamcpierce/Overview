/*
 Diagnostic/DiagnosticService.swift
 Overview

 Created by William Pierce on 2/17/25.

 Manages the generation and export of diagnostic reports while preserving user privacy.
*/

import AppKit
import ScreenCaptureKit
import SwiftUI

@MainActor
final class DiagnosticService {
    // Dependencies
    private let logger = AppLogger.interface

    // Singleton
    static let shared = DiagnosticService()

    private init() {
        logger.debug("Initializing diagnostic service")
    }

    func generateDiagnosticReport() async throws -> String {
        logger.info("Starting diagnostic report generation")

        var yamlReport: [String] = []
        yamlReport.append("# Overview Diagnostic Report")
        yamlReport.append("generated_at: \(formatDate(Date()))")

        // App Information
        yamlReport.append("\napp_info:")
        for line in (try await getAppInfo()).split(separator: "\n") {
            yamlReport.append("  \(line)")
        }

        // System Information
        yamlReport.append("\nsystem_info:")
        for line in (try await getSystemInfo()).split(separator: "\n") {
            yamlReport.append("  \(line)")
        }

        // Permission Status
        yamlReport.append("\npermission_status:")
        for line in (try await getPermissionInfo()).split(separator: "\n") {
            yamlReport.append("  \(line)")
        }

        // Settings (excluding sensitive data)
        yamlReport.append("\nsettings:")
        for line in (try await getSettingsInfo()).split(separator: "\n") {
            yamlReport.append("  \(line)")
        }

        // Window Information
        yamlReport.append("\nwindow_status:")
        for line in (try await getWindowInfo()).split(separator: "\n") {
            yamlReport.append("  \(line)")
        }

        let reportText = yamlReport.joined(separator: "\n")
        logger.info("Diagnostic report generation completed")

        return reportText
    }

    func saveDiagnosticReport(_ report: String) async throws -> URL {
        let filename = "Overview-Diagnostic-\(formatDate(Date(), forFilename: true)).yaml"

        guard
            let downloadsURL = FileManager.default.urls(
                for: .downloadsDirectory, in: .userDomainMask
            ).first
        else {
            throw DiagnosticError.fileSystemError
        }

        let fileURL = downloadsURL.appendingPathComponent(filename)

        do {
            try report.write(to: fileURL, atomically: true, encoding: .utf8)
            logger.info("Diagnostic report saved: \(filename)")
            return fileURL
        } catch {
            logger.logError(error, context: "Failed to save diagnostic report")
            throw DiagnosticError.fileSystemError
        }
    }

    // MARK: - Private Methods

    private func getAppInfo() async throws -> String {
        var info: [String] = []

        let bundle = Bundle.main
        info.append(
            "version: \(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")"
        )
        info.append(
            "build: \(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown")"
        )
        info.append("bundle_id: \(bundle.bundleIdentifier ?? "unknown")")

        return info.joined(separator: "\n")
    }

    private func getSystemInfo() async throws -> String {
        var info: [String] = []

        let processInfo = ProcessInfo.processInfo
        info.append("macos_version: \(processInfo.operatingSystemVersionString)")
        info.append("cpu_cores: \(processInfo.processorCount)")
        info.append("physical_memory: \(formatMemory(processInfo.physicalMemory))")
        info.append("thermal_state: \(getThermalState(processInfo.thermalState))")
        info.append("system_uptime: \(formatUptime(processInfo.systemUptime))")
        info.append("app_memory_usage: \(formatMemory(UInt64(processInfo.physicalMemory)))")

        // Metal capability check
        if #available(macOS 13.0, *) {
            let hasMetalSupport = MTLCreateSystemDefaultDevice() != nil
            info.append("metal_support: \(hasMetalSupport)")
        }

        // Display information
        let screens = NSScreen.screens
        info.append("display_count: \(screens.count)")

        for (index, screen) in screens.enumerated() {
            let size = screen.frame.size
            let scale = screen.backingScaleFactor
            info.append("display_\(index + 1):")
            info.append("  resolution: \(Int(size.width))x\(Int(size.height))")
            info.append("  scale_factor: \(scale)")
            info.append("  refresh_rate: \(getRefreshRate(for: screen)) Hz")
        }

        // Additional hardware capabilities
        if let gpuInfo = getGPUInfo() {
            info.append("gpu_info:")
            for line in gpuInfo.split(separator: "\n") {
                info.append("  \(line)")
            }
        }

        return info.joined(separator: "\n")
    }

    private func getPermissionInfo() async throws -> String {
        var info: [String] = []

        let screenCaptureStatus = CGPreflightScreenCaptureAccess() ? "granted" : "denied"
        info.append("screen_recording: \(screenCaptureStatus)")

        return info.joined(separator: "\n")
    }

    private func getSettingsInfo() async throws -> String {
        var info: [String] = []
        let defaults = UserDefaults.standard

        // Performance Settings
        info.append("performance:")
        info.append(
            "  frame_rate: \(defaults.double(forKey: PreviewSettingsKeys.captureFrameRate))")
        info.append(
            "  preview_opacity: \(Int(defaults.double(forKey: WindowSettingsKeys.previewOpacity) * 100))%"
        )

        // Window Behavior
        info.append("window_behavior:")
        info.append(
            "  mission_control_integration: \(defaults.bool(forKey: WindowSettingsKeys.managedByMissionControl))"
        )
        info.append(
            "  create_on_launch: \(defaults.bool(forKey: WindowSettingsKeys.createOnLaunch))")
        info.append(
            "  close_with_source: \(defaults.bool(forKey: WindowSettingsKeys.closeOnCaptureStop))")
        info.append(
            "  show_on_all_desktops: \(defaults.bool(forKey: WindowSettingsKeys.assignPreviewsToAllDesktops))"
        )

        // Overlay Settings
        info.append("overlay:")
        info.append(
            "  focus_border: \(defaults.bool(forKey: OverlaySettingsKeys.focusBorderEnabled))")
        info.append(
            "  source_title: \(defaults.bool(forKey: OverlaySettingsKeys.sourceTitleEnabled))")
        info.append(
            "  title_location: \(defaults.bool(forKey: OverlaySettingsKeys.sourceTitleLocation) ? "upper" : "lower")"
        )

        // Update Settings
        info.append("updates:")
        info.append("  auto_check: \(defaults.bool(forKey: "SUEnableAutomaticChecks"))")
        info.append("  auto_download: \(defaults.bool(forKey: "SUAutomaticallyUpdate"))")
        info.append(
            "  beta_updates: \(defaults.bool(forKey: UpdateSettingsKeys.enableBetaUpdates))")

        return info.joined(separator: "\n")
    }

    private func getWindowInfo() async throws -> String {
        var info: [String] = []

        // Window Statistics
        let allWindows = NSApp.windows
        let windowCount = allWindows.count
        let visibleWindows = allWindows.filter { $0.isVisible }.count

        info.append("statistics:")
        info.append("  total_windows: \(windowCount)")
        info.append("  visible_windows: \(visibleWindows)")

        // Preview Windows
        let previewWindows = allWindows.filter {
            $0.contentView?.ancestorOrSelf(ofType: NSHostingView<PreviewView>.self) != nil
        }

        info.append("preview_windows:")
        info.append("  active_count: \(previewWindows.count)")

        for (index, window) in previewWindows.enumerated() {
            info.append("  preview_window_\(index + 1):")
            info.append("    size: \(Int(window.frame.width))x\(Int(window.frame.height))")
            info.append("    screen: \(getScreenIndex(for: window))")
            info.append("    visible: \(window.isVisible)")
            info.append("    level: \(window.level.rawValue)")
            info.append("    collects_input: \(window.acceptsMouseMovedEvents)")
        }

        return info.joined(separator: "\n")
    }

    // MARK: - Additional Diagnostic Methods

    private func getGPUInfo() -> String? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }

        var info: [String] = []
        info.append("name: \(device.name)")
        info.append(
            "recommended_memory: \(formatMemory(UInt64(device.recommendedMaxWorkingSetSize)))")
        info.append("unified_memory: \(device.hasUnifiedMemory)")

        return info.joined(separator: "\n")
    }

    private func getRefreshRate(for screen: NSScreen) -> Int {
        let deviceDescription = screen.deviceDescription
        let refreshRate =
            deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")]
            as? CGDirectDisplayID
        var actualRate: Int32 = 0

        if let refreshRate = refreshRate,
            let mode = CGDisplayCopyDisplayMode(refreshRate)
        {
            actualRate = Int32(mode.refreshRate)
        }

        return Int(actualRate)
    }

    private func getThermalState(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private func getScreenIndex(for window: NSWindow) -> String {
        guard let windowScreen = window.screen else { return "none" }
        guard let screenIndex = NSScreen.screens.firstIndex(of: windowScreen) else {
            return "unknown"
        }
        return "\(screenIndex + 1)"
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds / 86400)
        let hours = Int((seconds.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date, forFilename: Bool = false) -> String {
        let formatter = DateFormatter()
        if forFilename {
            formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        } else {
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
        return formatter.string(from: date)
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        let gigabytes = Double(bytes) / 1_073_741_824  // 1024^3
        return String(format: "%.1f", gigabytes)
    }
}

// MARK: - Support Types

enum DiagnosticError: LocalizedError {
    case fileSystemError

    var errorDescription: String? {
        switch self {
        case .fileSystemError:
            return "Failed to access file system for report generation"
        }
    }
}
