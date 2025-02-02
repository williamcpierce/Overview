/*
 Logging/AppLogger.swift
 Overview

 Created by William Pierce on 12/11/24.
*/

import OSLog

struct AppLogger {
    private static let loggers: [Category: Logger] = Category.allCases.reduce(into: [:]) {
        dict, category in
        dict[category] = Logger(subsystem: subsystem, category: category.rawValue)
    }
    private static let subsystem: String = Bundle.main.bundleIdentifier ?? "com.Overview"

    static let capture: CategoryLogger = CategoryLogger(category: .capture)
    static let hotkeys: CategoryLogger = CategoryLogger(category: .hotkeys)
    static let interface: CategoryLogger = CategoryLogger(category: .interface)
    static let performance: CategoryLogger = CategoryLogger(category: .performance)
    static let settings: CategoryLogger = CategoryLogger(category: .settings)
    static let sources: CategoryLogger = CategoryLogger(category: .sources)
}

extension AppLogger {
    enum Category: String, CaseIterable {
        case capture = "Capture"
        case hotkeys = "Hotkeys"
        case interface = "Interface"
        case performance = "Performance"
        case settings = "Settings"
        case sources = "Sources"
    }

    enum Level {
        case debug
        case error
        case fault
        case info
        case warning

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .fault: return .fault
            case .info: return .info
            case .warning, .error: return .error
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
//        #if !DEBUG
//            guard level == .error || level == .fault else { return }
//        #endif

        let formattedMessage: String = "\(location.description) \(message)"
        loggers[category]?.log(level: level.osLogType, "\(formattedMessage)")
    }

    static func logError(
        _ error: Error,
        context: String? = nil,
        category: Category,
        location: SourceLocation
    ) {
        var message: String = "\(location.description) Error: \(error.localizedDescription)"
        if let context: String = context {
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

    func error(_ message: String, file: String = #file, function: String = #function) {
        log(message, level: .error, location: .init(file: file, function: function))
    }

    func fault(_ message: String, file: String = #file, function: String = #function) {
        log(message, level: .fault, location: .init(file: file, function: function))
    }

    func info(_ message: String, file: String = #file, function: String = #function) {
        log(message, level: .info, location: .init(file: file, function: function))
    }

    func warning(_ message: String, file: String = #file, function: String = #function) {
        log(message, level: .warning, location: .init(file: file, function: function))
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
