# Overview Logging Standards

## Introduction

This document outlines the logging standards for the Overview application using the centralized `AppLogger` system. These standards ensure consistent, meaningful, and maintainable logging across all components of the application.

## Logging System Overview

The Overview application uses a centralized logging system built on `OSLog` with the following key components:

- **AppLogger**: Central logging coordinator
- **Category-specific loggers**: Dedicated loggers for different application domains
- **Semantic log levels**: Clearly defined logging levels with specific use cases
- **Consistent formatting**: Standardized log message structure
- **Automatic context capture**: File and function information included in logs

## Log Categories

Each domain of the application has a dedicated logger:

- `AppLogger.capture`: Window capture and frame processing
- `AppLogger.windows`: Window management operations
- `AppLogger.hotkeys`: Keyboard shortcut handling
- `AppLogger.settings`: User preferences and configuration
- `AppLogger.performance`: Performance metrics and optimization
- `AppLogger.interface`: UI interactions and state management

## Log Levels

Use the appropriate semantic log level based on the following guidelines:

### Debug
- Detailed information useful during development
- Implementation details and state transitions
- Temporary logging for troubleshooting
```swift
AppLogger.capture.debug("Starting frame capture for window: \(windowId)")
```

### Info
- General operational messages
- Major state changes
- User-triggered actions
```swift
AppLogger.settings.info("User updated frame rate preference to \(newRate) FPS")
```

### Warning
- Recoverable issues requiring attention
- Degraded functionality
- Potential problems
```swift
AppLogger.windows.warning("Window title cache miss for '\(title)'")
```

### Error
- Operation failures
- Exception conditions
- Unmet requirements
```swift
AppLogger.hotkeys.error("Failed to register hotkey: \(error.localizedDescription)")
```

### Fault
- Critical system failures
- Unrecoverable errors
- Application crashes
```swift
AppLogger.capture.fault("Critical failure in capture engine: \(error)")
```

## Logging Best Practices

### Message Format
1. Be specific and concise
2. Include relevant identifiers
3. Use proper grammar and punctuation
4. Avoid unnecessary technical details

Good:
```swift
AppLogger.windows.info("Window focused: '\(windowTitle)'")
```

Bad:
```swift
AppLogger.windows.info("win focus") // Too vague
AppLogger.windows.info("Successfully completed the window focus operation for the window with title '\(windowTitle)' at timestamp \(Date())") // Too verbose
```

### Context Information
1. Include relevant state information
2. Log both success and failure paths
3. Include error context when available
4. Use structured data when appropriate

```swift
// Error with context
AppLogger.logError(error, 
                  context: "Registering hotkey binding: \(binding.description)", 
                  logger: AppLogger.hotkeys)

// State transitions
AppLogger.windows.info("Window state changed: \(oldState) -> \(newState)")
```

### Performance Considerations
1. Use appropriate log levels
2. Avoid expensive string interpolation in debug logs
3. Batch related log messages when appropriate
4. Consider log volume in production

```swift
// Conditional expensive logging
if AppLogger.capture.isEnabled(type: .debug) {
    let details = expensiveOperation()
    AppLogger.capture.debug("Capture details: \(details)")
}
```

## Implementation Examples

### Capture Operations
```swift
class CaptureManager {
    func startCapture() async throws {
        AppLogger.capture.debug("Initializing capture for window: \(windowId)")
        
        do {
            try await initializeStream()
            AppLogger.capture.info("Capture stream started successfully")
        } catch {
            AppLogger.logError(error, 
                             context: "Stream initialization", 
                             logger: AppLogger.capture)
            throw error
        }
    }
}
```

### Window Management
```swift
class WindowManager {
    func focusWindow(withTitle title: String) -> Bool {
        AppLogger.windows.debug("Attempting to focus window: '\(title)'")
        
        guard let window = findWindow(title: title) else {
            AppLogger.windows.warning("No window found with title: '\(title)'")
            return false
        }
        
        let success = activateWindow(window)
        AppLogger.windows.info("Window focus \(success ? "succeeded" : "failed"): '\(title)'")
        return success
    }
}
```

### Settings Management
```swift
class AppSettings {
    func updateFrameRate(_ newRate: Double) {
        AppLogger.settings.debug("Validating new frame rate: \(newRate)")
        
        guard isValidFrameRate(newRate) else {
            AppLogger.settings.warning("Invalid frame rate requested: \(newRate)")
            return
        }
        
        frameRate = newRate
        AppLogger.settings.info("Frame rate updated to \(newRate) FPS")
    }
}
```

## Monitoring and Debugging

### Console Access
View logs in Console.app by:
1. Filtering subsystem: "com.Overview"
2. Selecting relevant categories
3. Setting appropriate log level visibility

### Debug Commands
Export logs for troubleshooting:
```bash
log show --predicate 'subsystem == "com.Overview"' --last 30m
```

### Integration Tips
1. Use Xcode console during development
2. Set up log persistence for production
3. Consider adding crash reporting integration
4. Implement log aggregation for production monitoring

## Maintenance Guidelines

1. Review logs periodically for quality and usefulness
2. Update category organization as needed
3. Maintain consistent formatting across new code
4. Remove or update obsolete logging
5. Consider log rotation and cleanup in production

## Future Considerations

1. Log aggregation service integration
2. Performance metric tracking
3. User session correlation
4. Analytics integration
5. Remote logging capabilities

Remember that logging is a critical debugging tool. Well-structured logs significantly reduce troubleshooting time and improve application maintainability.
