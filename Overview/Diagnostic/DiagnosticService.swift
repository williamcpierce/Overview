/*
 Diagnostic/DiagnosticService.swift
 Overview

 Created by William Pierce on 2/17/25.

 Manages the generation and export of diagnostic reports while preserving user privacy.
*/

import AppKit
import KeyboardShortcuts
import OSLog
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
            windowStatus: try await getWindowInfo(),
            shortcuts: try await getShortcutsInfo()
        )

        let jsonData = try jsonEncoder.encode(report)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw DiagnosticError.encodingError
        }

        logger.info("Diagnostic report generation completed")
        return jsonString
    }

    func saveDiagnosticReport(_ report: String) async throws -> URL {
        let filename = "Overview-Diagnostic-\(formatDate(Date(), forFilename: true))"
        let reportFilename = "\(filename).json"
        let logFilename = "\(filename)-logs.txt"

        guard
            let documentsURL = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first
        else {
            throw DiagnosticError.fileSystemError
        }

        let overviewDirURL = documentsURL.appendingPathComponent("Overview")
        try FileManager.default.createDirectory(
            at: overviewDirURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let reportURL = overviewDirURL.appendingPathComponent(reportFilename)
        try report.write(to: reportURL, atomically: true, encoding: .utf8)
        logger.info("Diagnostic report saved: \(reportFilename)")

        let logURL = overviewDirURL.appendingPathComponent(logFilename)
        try await saveLogFile(to: logURL)
        logger.info("Log file saved: \(logFilename)")

        return reportURL
    }

    private func saveLogFile(to url: URL) async throws {
        guard let store = try? OSLogStore(scope: .currentProcessIdentifier) else {
            throw DiagnosticError.logStoreAccessError
        }

        let startTime = Date.distantPast
        let position = store.position(date: startTime)

        let bundleID = Bundle.main.bundleIdentifier ?? "Overview"
        var entries: [OSLogEntryLog] = []

        for entry in try store.getEntries(at: position) {
            guard let logEntry = entry as? OSLogEntryLog,
                logEntry.subsystem == bundleID
            else { continue }
            entries.append(logEntry)
        }

        let logText = entries.map {
            "[\($0.date.formatted())] [\($0.category)] \($0.composedMessage)"
        }
        .joined(separator: "\n")
        try logText.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Information Gathering

    private func getAppInfo() async throws -> AppInfo {
        let bundle = Bundle.main
        return AppInfo(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                ?? "unknown",
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
            screenRecording: CGPreflightScreenCaptureAccess() ? "granted" : "denied"
        )
    }

    private func getSettingsInfo() async throws -> SettingsInfo {
        let defaults = UserDefaults.standard

        return SettingsInfo(
            preview: PreviewSettings(
                frameRate: defaults.double(forKey: PreviewSettingsKeys.captureFrameRate),
                hideInactiveApplications: defaults.bool(
                    forKey: PreviewSettingsKeys.hideInactiveApplications),
                hideActiveWindow: defaults.bool(forKey: PreviewSettingsKeys.hideActiveWindow)
            ),
            window: WindowSettings(
                opacity: Int(defaults.double(forKey: WindowSettingsKeys.previewOpacity) * 100),
                defaultWidth: Int(defaults.double(forKey: WindowSettingsKeys.defaultWidth)),
                defaultHeight: Int(defaults.double(forKey: WindowSettingsKeys.defaultHeight)),
                shadows: defaults.bool(forKey: WindowSettingsKeys.shadowEnabled),
                missionControlIntegration: defaults.bool(
                    forKey: WindowSettingsKeys.managedByMissionControl),
                createOnLaunch: defaults.bool(forKey: WindowSettingsKeys.createOnLaunch),
                closeWithSource: defaults.bool(forKey: WindowSettingsKeys.closeOnCaptureStop),
                showOnAllDesktops: defaults.bool(
                    forKey: WindowSettingsKeys.assignPreviewsToAllDesktops),
                savePositionsOnClose: defaults.bool(forKey: WindowSettingsKeys.savePositionsOnClose)
            ),
            overlay: OverlaySettings(
                focusBorder: FocusBorderSettings(
                    enabled: defaults.bool(forKey: OverlaySettingsKeys.focusBorderEnabled),
                    width: Int(defaults.double(forKey: OverlaySettingsKeys.focusBorderWidth))
                ),
                sourceTitle: SourceTitleSettings(
                    enabled: defaults.bool(forKey: OverlaySettingsKeys.sourceTitleEnabled),
                    fontSize: Int(defaults.double(forKey: OverlaySettingsKeys.sourceTitleFontSize)),
                    backgroundOpacity: Int(
                        defaults.double(forKey: OverlaySettingsKeys.sourceTitleBackgroundOpacity)
                            * 100),
                    location: defaults.bool(forKey: OverlaySettingsKeys.sourceTitleLocation)
                        ? "upper" : "lower",
                    type: defaults.string(forKey: OverlaySettingsKeys.sourceTitleType)
                        ?? TitleType.windowTitle
                )
            ),
            source: SourceSettings(
                filterMode: defaults.bool(forKey: SourceSettingsKeys.filterMode)
                    ? "blocklist" : "allowlist",
                filterAppNames: defaults.stringArray(forKey: SourceSettingsKeys.appNames) ?? []
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

    private func getShortcutsInfo() async throws -> ShortcutsInfo {
        let shortcutItems = ShortcutStorage.shared.shortcuts
        return ShortcutsInfo(
            shortcuts: shortcutItems.map { shortcut in
                ShortcutDiagnostic(
                    id: shortcut.id.uuidString,
                    windowTitles: shortcut.windowTitles,
                    keyboardShortcut: KeyboardShortcuts.getShortcut(for: shortcut.shortcutName)?
                        .description ?? "unset"
                )
            }
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

    private func formatDate(_ date: Date, forFilename: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = forFilename ? "yyyy-MM-dd-HHmmss" : "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        let gigabytes = Double(bytes) / 1_073_741_824
        /// 1024^3
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
    let shortcuts: ShortcutsInfo
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
}

struct SettingsInfo: Codable {
    let preview: PreviewSettings
    let window: WindowSettings
    let overlay: OverlaySettings
    let source: SourceSettings
    let updates: UpdateSettings
}

struct PreviewSettings: Codable {
    let frameRate: Double
    let hideInactiveApplications: Bool
    let hideActiveWindow: Bool
}

struct WindowSettings: Codable {
    let opacity: Int
    let defaultWidth: Int
    let defaultHeight: Int
    let shadows: Bool
    let missionControlIntegration: Bool
    let createOnLaunch: Bool
    let closeWithSource: Bool
    let showOnAllDesktops: Bool
    let savePositionsOnClose: Bool
}

struct OverlaySettings: Codable {
    let focusBorder: FocusBorderSettings
    let sourceTitle: SourceTitleSettings
}

struct FocusBorderSettings: Codable {
    let enabled: Bool
    let width: Int
}

struct SourceTitleSettings: Codable {
    let enabled: Bool
    let fontSize: Int
    let backgroundOpacity: Int
    let location: String
    let type: String
}

struct SourceSettings: Codable {
    let filterMode: String
    let filterAppNames: [String]
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

struct ShortcutsInfo: Codable {
    let shortcuts: [ShortcutDiagnostic]
}

struct ShortcutDiagnostic: Codable {
    let id: String
    let windowTitles: [String]
    let keyboardShortcut: String
}

// MARK: - Error Types

enum DiagnosticError: LocalizedError {
    case fileSystemError
    case encodingError
    case logStoreAccessError

    var errorDescription: String? {
        switch self {
        case .fileSystemError:
            return "Failed to access file system for report generation"
        case .encodingError:
            return "Failed to encode diagnostic report to JSON"
        case .logStoreAccessError:
            return "Failed to access system log store"
        }
    }
}
