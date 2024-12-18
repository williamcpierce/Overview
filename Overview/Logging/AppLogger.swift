/*
 AppLogger.swift
 Overview

 Created by William Pierce on 12/11/24.

 Provides centralized logging functionality across the application using OSLog,
 ensuring consistent log formatting, categorization, and level management.
*/

import Foundation
import OSLog

struct AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.Overview"

    private static let loggers: [Category: Logger] = Category.allCases.reduce(into: [:]) {
        dict, category in
        dict[category] = Logger(subsystem: subsystem, category: category.rawValue)
    }

    static let capture = CategoryLogger(category: .capture)
    static let windows = CategoryLogger(category: .windows)
    static let hotkeys = CategoryLogger(category: .hotkeys)
    static let settings = CategoryLogger(category: .settings)
    static let performance = CategoryLogger(category: .performance)
    static let interface = CategoryLogger(category: .interface)
}

extension AppLogger {
    enum Category: String, CaseIterable {
        case capture = "Capture"
        case windows = "Windows"
        case hotkeys = "Hotkeys"
        case settings = "Settings"
        case performance = "Performance"
        case interface = "Interface"
    }

    enum Level {
        case debug
        case info
        case warning
        case error
        case fault

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning, .error: return .error
            case .fault: return .fault
            }
        }
    }
}

extension AppLogger {
    struct SourceLocation {
        let file: String
        let function: String

        var fileName: String {
            URL(fileURLWithPath: file).lastPathComponent
        }

        var description: String {
            "[\(fileName):\(function)]"
        }
    }

    static func log(
        _ message: String,
        level: Level,
        category: Category,
        location: SourceLocation
    ) {
        #if !DEBUG
            guard level == .error || level == .fault else { return }
        #endif

        let formattedMessage = "\(location.description) \(message)"
        loggers[category]?.log(level: level.osLogType, "\(formattedMessage)")
    }

    static func logError(
        _ error: Error,
        context: String? = nil,
        category: Category,
        location: SourceLocation
    ) {
        var message = "\(location.description) Error: \(error.localizedDescription)"
        if let context = context {
            message += " - Context: \(context)"
        }

        loggers[category]?.error("\(message)")
    }
}

struct CategoryLogger {
    private let category: AppLogger.Category

    init(category: AppLogger.Category) {
        self.category = category
    }

    private func log(
        _ message: String,
        level: AppLogger.Level,
        location: AppLogger.SourceLocation = .init(file: #file, function: #function)
    ) {
        AppLogger.log(message, level: level, category: category, location: location)
    }
}

extension CategoryLogger {
    func debug(_ message: String, file: String = #file, function: String = #function) {
        log(message, level: .debug, location: .init(file: file, function: function))
    }

    func info(_ message: String, file: String = #file, function: String = #function) {
        log(message, level: .info, location: .init(file: file, function: function))
    }

    func warning(_ message: String, file: String = #file, function: String = #function) {
        log(message, level: .warning, location: .init(file: file, function: function))
    }

    func error(_ message: String, file: String = #file, function: String = #function) {
        log(message, level: .error, location: .init(file: file, function: function))
    }

    func fault(_ message: String, file: String = #file, function: String = #function) {
        log(message, level: .fault, location: .init(file: file, function: function))
    }
}

extension CategoryLogger {
    func logError(
        _ error: Error,
        context: String? = nil,
        file: String = #file,
        function: String = #function
    ) {
        AppLogger.logError(
            error,
            context: context,
            category: category,
            location: .init(file: file, function: function)
        )
    }
}
