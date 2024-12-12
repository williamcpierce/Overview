/*
 AppLogger.swift
 Overview
 
 Created by William Pierce on 12/11/24.
 
 Provides centralized logging functionality across the application using OSLog,
 ensuring consistent log formatting, categorization, and level management.
 
 This file is part of Overview.
 
 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import OSLog
import Foundation

/// Centralized logging system for Overview application
///
/// Key responsibilities:
/// - Provides consistent logging interface across components
/// - Manages log categories and subsystem organization
/// - Ensures proper log level usage and formatting
/// - Maintains debugging context for log entries
///
/// Usage:
/// ```swift
/// // Basic logging with category
/// AppLogger.capture.debug("Starting frame capture")
///
/// // Structured logging with context
/// AppLogger.log("User preference updated",
///              level: .info,
///              logger: AppLogger.settings)
///
/// // Error logging with context
/// AppLogger.log("Failed to register hotkey: \(error)",
///              level: .error,
///              logger: AppLogger.hotkeys)
/// ```
struct AppLogger {
    // MARK: - Properties
    
    /// Application-wide subsystem identifier for log organization
    private static let subsystem = "com.Overview"
    
    // MARK: - Category Loggers
    
    /// Logging for capture operations and frame processing
    static let capture = Logger(subsystem: subsystem, category: "Capture")
    
    /// Logging for window management and focus operations
    static let windows = Logger(subsystem: subsystem, category: "Windows")
    
    /// Logging for hotkey registration and event handling
    static let hotkeys = Logger(subsystem: subsystem, category: "Hotkeys")
    
    /// Logging for user settings and preferences
    static let settings = Logger(subsystem: subsystem, category: "Settings")
    
    /// Logging for performance metrics and optimization
    static let performance = Logger(subsystem: subsystem, category: "Performance")
    
    /// Logging for UI interactions and state management
    static let interface = Logger(subsystem: subsystem, category: "Interface")
    
    // MARK: - Log Levels
    
    /// Semantic log levels with consistent OSLog mapping
    enum Level {
        /// Detailed information for debugging purposes
        case debug
        
        /// General information about program execution
        case info
        
        /// Potentially harmful situations requiring attention
        case warning
        
        /// Error events that might still allow the application to continue
        case error
        
        /// Very severe error events that may lead to application termination
        case fault
        
        /// Maps semantic levels to OSLog types
        fileprivate var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .error
            case .error: return .error
            case .fault: return .fault
            }
        }
    }
    
    // MARK: - Logging Methods
    
    /// Logs a message with consistent formatting and context
    ///
    /// Flow:
    /// 1. Extracts file name from path
    /// 2. Formats message with context
    /// 3. Logs through appropriate category logger
    ///
    /// - Parameters:
    ///   - message: Content to log
    ///   - level: Semantic logging level
    ///   - logger: Category-specific logger instance
    ///   - file: Source file (automatically provided)
    ///   - function: Calling function (automatically provided)
    static func log(
        _ message: String,
        level: Level,
        logger: Logger,
        file: String = #file,
        function: String = #function
    ) {
        let fileURL = URL(fileURLWithPath: file)
        let fileName = fileURL.lastPathComponent
        let logMessage = "[\(fileName):\(function)] \(message)"
        
        logger.log(level: level.osLogType, "\(logMessage)")
    }
    
    /// Logs an error with additional context and formatting
    ///
    /// Flow:
    /// 1. Extracts error details and context
    /// 2. Formats comprehensive error message
    /// 3. Logs through error-specific logger
    ///
    /// - Parameters:
    ///   - error: Error instance to log
    ///   - context: Additional error context
    ///   - logger: Category-specific logger instance
    ///   - file: Source file (automatically provided)
    ///   - function: Calling function (automatically provided)
    static func logError(
        _ error: Error,
        context: String? = nil,
        logger: Logger,
        file: String = #file,
        function: String = #function
    ) {
        let fileURL = URL(fileURLWithPath: file)
        let fileName = fileURL.lastPathComponent
        
        var message = "[\(fileName):\(function)] Error: \(error.localizedDescription)"
        if let context = context {
            message += " - Context: \(context)"
        }
        
        logger.error("\(message)")
    }
}

// MARK: - Convenience Extensions

extension Logger {
    /// Logs debug message with consistent formatting
    func debug(_ message: String, file: String = #file, function: String = #function) {
        AppLogger.log(message, level: .debug, logger: self, file: file, function: function)
    }
    
    /// Logs info message with consistent formatting
    func info(_ message: String, file: String = #file, function: String = #function) {
        AppLogger.log(message, level: .info, logger: self, file: file, function: function)
    }
    
    /// Logs warning message with consistent formatting
    func warning(_ message: String, file: String = #file, function: String = #function) {
        AppLogger.log(message, level: .warning, logger: self, file: file, function: function)
    }
    
    /// Logs error message with consistent formatting
    func error(_ message: String, file: String = #file, function: String = #function) {
        AppLogger.log(message, level: .error, logger: self, file: file, function: function)
    }
    
    /// Logs fault message with consistent formatting
    func fault(_ message: String, file: String = #file, function: String = #function) {
        AppLogger.log(message, level: .fault, logger: self, file: file, function: function)
    }
}
