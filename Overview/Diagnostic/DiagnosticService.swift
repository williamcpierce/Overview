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
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    // Singleton
    static let shared = DiagnosticService()

    private init() {
        logger.debug("Initializing diagnostic service")
    }

    func generateDiagnosticReport() async throws -> String {
        logger.info("Starting diagnostic report generation")

        let report = DiagnosticReport(
            generatedAt: formatDate(Date()),
            appInfo: try await getAppInfo(),
            systemInfo: try await getSystemInfo(),
            permissionStatus: try await getPermissionInfo(),
            settings: try await getSettingsInfo(),
            windowStatus: try await getWindowInfo()
        )

        let jsonData = try jsonEncoder.encode(report)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw DiagnosticError.encodingError
        }

        logger.info("Diagnostic report generation completed")
        return jsonString
    }

    func saveDiagnosticReport(_ report: String) async throws -> URL {
        let filename = "Overview-Diagnostic-\(formatDate(Date(), forFilename: true)).json"

        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
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

    // MARK: - Information Gathering

    private func getAppInfo() async throws -> AppInfo {
        let bundle = Bundle.main
        return AppInfo(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            bundleId: bundle.bundleIdentifier ?? "unknown"
        )
    }

    private func getSystemInfo() async throws -> SystemInfo {
        let processInfo = ProcessInfo.processInfo
        let screens = NSScreen.screens

        return SystemInfo(
            macosVersion: processInfo.operatingSystemVersionString,
            cpuCores: processInfo.processorCount,
            physicalMemory: formatMemory(processInfo.physicalMemory),
            thermalState: getThermalState(processInfo.thermalState),
            systemUptime: formatUptime(processInfo.systemUptime),
            appMemoryUsage: formatMemory(UInt64(processInfo.physicalMemory)),
            metalSupport: MTLCreateSystemDefaultDevice() != nil,
            displayCount: screens.count,
            displays: screens.enumerated().map { index, screen in
                DisplayInfo(
                    id: index + 1,
                    resolution: Resolution(
                        width: Int(screen.frame.width),
                        height: Int(screen.frame.height)
                    ),
                    scaleFactor: screen.backingScaleFactor,
                    refreshRate: getRefreshRate(for: screen)
                )
            },
            gpuInfo: getGPUInfo()
        )
    }

    private func getPermissionInfo() async throws -> PermissionInfo {
        PermissionInfo(
            screenRecording: CGPreflightScreenCaptureAccess() ? "granted" : "denied",
            accessibility: AXIsProcessTrusted() ? "granted" : "denied"
        )
    }

    private func getSettingsInfo() async throws -> SettingsInfo {
        let defaults = UserDefaults.standard
        
        return SettingsInfo(
            performance: PerformanceSettings(
                frameRate: defaults.double(forKey: PreviewSettingsKeys.captureFrameRate),
                previewOpacity: Int(defaults.double(forKey: WindowSettingsKeys.previewOpacity) * 100)
            ),
            windowBehavior: WindowBehaviorSettings(
                missionControlIntegration: defaults.bool(forKey: WindowSettingsKeys.managedByMissionControl),
                createOnLaunch: defaults.bool(forKey: WindowSettingsKeys.createOnLaunch),
                closeWithSource: defaults.bool(forKey: WindowSettingsKeys.closeOnCaptureStop),
                showOnAllDesktops: defaults.bool(forKey: WindowSettingsKeys.assignPreviewsToAllDesktops)
            ),
            overlay: OverlaySettings(
                focusBorder: defaults.bool(forKey: OverlaySettingsKeys.focusBorderEnabled),
                sourceTitle: defaults.bool(forKey: OverlaySettingsKeys.sourceTitleEnabled),
                titleLocation: defaults.bool(forKey: OverlaySettingsKeys.sourceTitleLocation) ? "upper" : "lower"
            ),
            updates: UpdateSettings(
                autoCheck: defaults.bool(forKey: "SUEnableAutomaticChecks"),
                autoDownload: defaults.bool(forKey: "SUAutomaticallyUpdate"),
                betaUpdates: defaults.bool(forKey: UpdateSettingsKeys.enableBetaUpdates)
            )
        )
    }

    private func getWindowInfo() async throws -> WindowStatus {
        let allWindows = NSApp.windows
        let previewWindows = allWindows.filter {
            $0.contentView?.ancestorOrSelf(ofType: NSHostingView<PreviewView>.self) != nil
        }

        return WindowStatus(
            statistics: WindowStatistics(
                totalWindows: allWindows.count,
                visibleWindows: allWindows.filter { $0.isVisible }.count
            ),
            previewWindows: PreviewWindowInfo(
                activeCount: previewWindows.count,
                windows: previewWindows.enumerated().map { index, window in
                    PreviewWindow(
                        id: index + 1,
                        size: Resolution(
                            width: Int(window.frame.width),
                            height: Int(window.frame.height)
                        ),
                        screen: getScreenIndex(for: window),
                        visible: window.isVisible,
                        level: window.level.rawValue,
                        collectsInput: window.acceptsMouseMovedEvents
                    )
                }
            )
        )
    }

    // MARK: - Helper Methods

    private func getGPUInfo() -> GPUInfo? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        
        return GPUInfo(
            name: device.name,
            recommendedMemory: formatMemory(UInt64(device.recommendedMaxWorkingSetSize)),
            unifiedMemory: device.hasUnifiedMemory
        )
    }

    private func getRefreshRate(for screen: NSScreen) -> Int {
        let deviceDescription = screen.deviceDescription
        let refreshRate = deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID
        var actualRate: Int32 = 0

        if let refreshRate = refreshRate,
           let mode = CGDisplayCopyDisplayMode(refreshRate) {
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

    private func formatDate(_ date: Date, forFilename: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = forFilename ? "yyyy-MM-dd-HHmmss" : "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        let gigabytes = Double(bytes) / 1_073_741_824  // 1024^3
        return String(format: "%.1f", gigabytes)
    }
}

// MARK: - Report Models

struct DiagnosticReport: Codable {
    let generatedAt: String
    let appInfo: AppInfo
    let systemInfo: SystemInfo
    let permissionStatus: PermissionInfo
    let settings: SettingsInfo
    let windowStatus: WindowStatus
}

struct AppInfo: Codable {
    let version: String
    let build: String
    let bundleId: String
}

struct SystemInfo: Codable {
    let macosVersion: String
    let cpuCores: Int
    let physicalMemory: String
    let thermalState: String
    let systemUptime: String
    let appMemoryUsage: String
    let metalSupport: Bool
    let displayCount: Int
    let displays: [DisplayInfo]
    let gpuInfo: GPUInfo?
}

struct DisplayInfo: Codable {
    let id: Int
    let resolution: Resolution
    let scaleFactor: Double
    let refreshRate: Int
}

struct Resolution: Codable {
    let width: Int
    let height: Int
}

struct GPUInfo: Codable {
    let name: String
    let recommendedMemory: String
    let unifiedMemory: Bool
}

struct PermissionInfo: Codable {
    let screenRecording: String
    let accessibility: String
}

struct SettingsInfo: Codable {
    let performance: PerformanceSettings
    let windowBehavior: WindowBehaviorSettings
    let overlay: OverlaySettings
    let updates: UpdateSettings
}

struct PerformanceSettings: Codable {
    let frameRate: Double
    let previewOpacity: Int
}

struct WindowBehaviorSettings: Codable {
    let missionControlIntegration: Bool
    let createOnLaunch: Bool
    let closeWithSource: Bool
    let showOnAllDesktops: Bool
}

struct OverlaySettings: Codable {
    let focusBorder: Bool
    let sourceTitle: Bool
    let titleLocation: String
}

struct UpdateSettings: Codable {
    let autoCheck: Bool
    let autoDownload: Bool
    let betaUpdates: Bool
}

struct WindowStatus: Codable {
    let statistics: WindowStatistics
    let previewWindows: PreviewWindowInfo
}

struct WindowStatistics: Codable {
    let totalWindows: Int
    let visibleWindows: Int
}

struct PreviewWindowInfo: Codable {
    let activeCount: Int
    let windows: [PreviewWindow]
}

struct PreviewWindow: Codable {
    let id: Int
    let size: Resolution
    let screen: String
    let visible: Bool
    let level: Int
    let collectsInput: Bool
}

// MARK: - Error Types

enum DiagnosticError: LocalizedError {
    case fileSystemError
    case encodingError

    var errorDescription: String? {
        switch self {
        case .fileSystemError:
            return "Failed to access file system for report generation"
        case .encodingError:
            return "Failed to encode diagnostic report to JSON"
        }
    }
}
