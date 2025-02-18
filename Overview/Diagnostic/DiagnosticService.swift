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
        
        var report = ["Overview Diagnostic Report"]
        report.append("Generated: \(formatDate(Date()))")
        report.append(String(repeating: "-", count: 40))
        
        // App Information
        report.append("\nApplication Info:")
        report.append(try await getAppInfo())
        
        // System Information
        report.append("\nSystem Info:")
        report.append(try await getSystemInfo())
        
        // Permission Status
        report.append("\nPermission Status:")
        report.append(try await getPermissionInfo())
        
        // Settings (excluding sensitive data)
        report.append("\nSettings Status:")
        report.append(try await getSettingsInfo())
        
        // Window Information
        report.append("\nWindow Status:")
        report.append(try await getWindowInfo())
        
        let reportText = report.joined(separator: "\n")
        logger.info("Diagnostic report generation completed")
        
        return reportText
    }
    
    func saveDiagnosticReport(_ report: String) async throws -> URL {
        let filename = "Overview-Diagnostic-\(formatDate(Date(), forFilename: true)).txt"
        
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
    
    // MARK: - Private Methods
    
    private func getAppInfo() async throws -> String {
        var info: [String] = []
        
        let bundle = Bundle.main
        info.append("Version: \(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")")
        info.append("Build: \(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")")
        info.append("Bundle ID: \(bundle.bundleIdentifier ?? "Unknown")")
        
        return info.joined(separator: "\n")
    }
    
    private func getSystemInfo() async throws -> String {
        var info: [String] = []
        
        let processInfo = ProcessInfo.processInfo
        info.append("macOS Version: \(processInfo.operatingSystemVersionString)")
        info.append("CPU Cores: \(processInfo.processorCount)")
        info.append("Physical Memory: \(formatMemory(processInfo.physicalMemory))")
        info.append("Thermal State: \(getThermalState(processInfo.thermalState))")
        info.append("System Uptime: \(formatUptime(processInfo.systemUptime))")
        info.append("App Memory Usage: \(formatMemory(UInt64(processInfo.physicalMemory)))")
        
        // Metal capability check
        if #available(macOS 13.0, *) {
            let hasMetalSupport = MTLCreateSystemDefaultDevice() != nil
            info.append("Metal Support: \(hasMetalSupport ? "Yes" : "No")")
        }
        
        // Display information
        let screens = NSScreen.screens
        info.append("Display Count: \(screens.count)")
        
        for (index, screen) in screens.enumerated() {
            let size = screen.frame.size
            let scale = screen.backingScaleFactor
            info.append("Display \(index + 1):")
            info.append("  Resolution: \(Int(size.width))x\(Int(size.height))")
            info.append("  Scale Factor: \(scale)x")
            info.append("  Refresh Rate: \(getRefreshRate(for: screen)) Hz")
        }
        
        // Additional hardware capabilities
        info.append("\nHardware Capabilities:")
        if let gpuInfo = getGPUInfo() {
            info.append(gpuInfo)
        }
        
        return info.joined(separator: "\n")
    }
    
    private func getPermissionInfo() async throws -> String {
        var info: [String] = []
        
        let screenCaptureStatus = CGPreflightScreenCaptureAccess() ? "Granted" : "Denied"
        info.append("Screen Recording: \(screenCaptureStatus)")
        
        return info.joined(separator: "\n")
    }
    
    private func getSettingsInfo() async throws -> String {
        var info: [String] = []
        let defaults = UserDefaults.standard
        
        // Performance Settings
        info.append("Performance Settings:")
        info.append("  Frame Rate: \(defaults.double(forKey: PreviewSettingsKeys.captureFrameRate))")
        info.append("  Preview Opacity: \(Int(defaults.double(forKey: WindowSettingsKeys.previewOpacity) * 100))%")
        
        // Window Behavior
        info.append("\nWindow Behavior:")
        info.append("  Mission Control Integration: \(defaults.bool(forKey: WindowSettingsKeys.managedByMissionControl))")
        info.append("  Create on Launch: \(defaults.bool(forKey: WindowSettingsKeys.createOnLaunch))")
        info.append("  Close with Source: \(defaults.bool(forKey: WindowSettingsKeys.closeOnCaptureStop))")
        info.append("  Show on All Desktops: \(defaults.bool(forKey: WindowSettingsKeys.assignPreviewsToAllDesktops))")
        
        // Overlay Settings
        info.append("\nOverlay Configuration:")
        info.append("  Focus Border: \(defaults.bool(forKey: OverlaySettingsKeys.focusBorderEnabled))")
        info.append("  Source Title: \(defaults.bool(forKey: OverlaySettingsKeys.sourceTitleEnabled))")
        info.append("  Title Location: \(defaults.bool(forKey: OverlaySettingsKeys.sourceTitleLocation) ? "Upper" : "Lower")")
        
        // Update Settings
        info.append("\nUpdate Configuration:")
        info.append("  Auto-Check Updates: \(defaults.bool(forKey: "SUEnableAutomaticChecks"))")
        info.append("  Auto-Download Updates: \(defaults.bool(forKey: "SUAutomaticallyUpdate"))")
        info.append("  Beta Updates: \(defaults.bool(forKey: UpdateSettingsKeys.enableBetaUpdates))")
        
        return info.joined(separator: "\n")
    }
    
    private func getWindowInfo() async throws -> String {
        var info: [String] = []
        
        // Window Statistics
        let allWindows = NSApp.windows
        let windowCount = allWindows.count
        let visibleWindows = allWindows.filter { $0.isVisible }.count
        
        info.append("Window Statistics:")
        info.append("  Total Windows: \(windowCount)")
        info.append("  Visible Windows: \(visibleWindows)")
        
        // Preview Windows
        let previewWindows = allWindows.filter {
            $0.contentView?.ancestorOrSelf(ofType: NSHostingView<PreviewView>.self) != nil
        }
        
        info.append("\nPreview Windows:")
        info.append("  Active Preview Count: \(previewWindows.count)")
        
        for (index, window) in previewWindows.enumerated() {
            info.append("\n  Preview Window \(index + 1):")
            info.append("    Size: \(Int(window.frame.width))x\(Int(window.frame.height))")
            info.append("    Screen: \(getScreenIndex(for: window))")
            info.append("    Visible: \(window.isVisible)")
            info.append("    Level: \(window.level.rawValue)")
            info.append("    Collects Input: \(window.acceptsMouseMovedEvents)")
        }
        
        return info.joined(separator: "\n")
    }

    // MARK: - Additional Diagnostic Methods
    
    private func getGPUInfo() -> String? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        
        var info: [String] = []
        info.append("GPU Name: \(device.name)")
        info.append("GPU Memory: \(formatMemory(UInt64(device.recommendedMaxWorkingSetSize)))")
        info.append("Unified Memory: \(device.hasUnifiedMemory)")
        
        return info.joined(separator: "\n")
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
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    
    private func getScreenIndex(for window: NSWindow) -> String {
        guard let windowScreen = window.screen else { return "None" }
        guard let screenIndex = NSScreen.screens.firstIndex(of: windowScreen) else { return "Unknown" }
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
        let gigabytes = Double(bytes) / 1_073_741_824 // 1024^3
        return String(format: "%.1f GB", gigabytes)
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
