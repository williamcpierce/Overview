# Documentation and Logging Style Guide

## Documentation Philosophy

Code should be primarily self-documenting through clear naming and logical structure. Comments should be used sparingly and only when the code's purpose cannot be made obvious through naming alone.

### File Headers

Each file should have a minimal header containing:

-   File path
-   Project name
-   Creation date and author
-   Brief description of the file's purpose (for complex components)
-   Copyright/license information if applicable

Example:

```swift
/*
 Capture/Services/CaptureServices.swift
 Overview

 Created by William Pierce on 12/27/24.

 A centralized service that coordinates capture-related operations,
 including permission management and stream configuration.
*/
```

### Code Organization

Use `// MARK: -` comments to organize larger files into logical sections. These should group related properties and methods.

Example:

```swift
// MARK: - Published State
@Published private(set) var isCapturing: Bool = false
@Published private(set) var windowTitle: String?

// MARK: - Dependencies
private let appSettings: AppSettings
private let windowManager: WindowManager
```

### Type Documentation

Complex types should have a brief descriptor comment explaining their purpose and responsibilities. Simple types (like basic enums or small structs) don't need documentation.

Example:

```swift
/// Manages the lifecycle and configuration of screen capture streams,
/// handling frame processing and error management for captured content.
class CaptureEngine: NSObject, @unchecked Sendable {
    // Implementation
}

/// Coordinates window-related services including filtering, focus management,
/// and state observation across the application.
@MainActor
final class WindowServices {
    // Implementation
}
```

### Method Documentation

Methods should generally not require documentation. Instead:

-   Use clear, descriptive method names that indicate purpose
-   Break complex logic into well-named helper methods
-   Use type signatures to convey parameter requirements
-   Only add documentation for complex algorithms or non-obvious side effects

## Logging Standards

### Logger Configuration

Each class/struct should have a single private logger instance configured for its appropriate category:

```swift
private let logger = AppLogger.capture  // For capture-related components
private let logger = AppLogger.interface // For UI-related components
private let logger = AppLogger.windows   // For window management
private let logger = AppLogger.settings  // For settings management
private let logger = AppLogger.hotkeys   // For hotkey functionality
```

### Log Levels

Use appropriate log levels based on the information's importance:

-   **debug**: Development-time information, disabled in release builds

    ```swift
    logger.debug("Created layer-backed NSView for frame rendering")
    ```

-   **info**: Important state changes and operations

    ```swift
    logger.info("Screen recording permission granted")
    ```

-   **warning**: Recoverable issues that might indicate problems

    ```swift
    logger.warning("No process ID found for window: '\(window.title ?? "untitled")'")
    ```

-   **error**: Significant failures that affect functionality
    ```swift
    logger.error("Failed to register hotkeys: \(error.localizedDescription)")
    ```

### Logging Best Practices

1. **Be Selective**: Log meaningful state changes and important operations, not routine method calls
2. **Use Debug Level**: For detailed information needed during development
3. **Include Context**: Log relevant identifiers and values that aid troubleshooting
4. **Error Handling**: Use `logError` with context for error conditions
    ```swift
    logger.logError(error, context: "Failed to update stream configuration")
    ```
5. **Performance**: Avoid logging in tight loops or high-frequency operations

### Examples of Good Logging

```swift
// State changes
logger.info("Window opacity updated to \(Int(windowOpacity * 100))%")

// Operation results
logger.info("Retrieved \(filteredWindows.count) windows for binding")

// Initialization
logger.debug("Initializing capture services")

// Error conditions with context
logger.error("Stream stopped with error: \(error.localizedDescription)")
```
