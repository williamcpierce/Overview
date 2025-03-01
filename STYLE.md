# Documentation and Logging Style Guide

## Documentation Philosophy

Code should be primarily self-documenting through clear naming and logical structure. Comments should be used sparingly and only when the code's purpose cannot be made obvious through naming alone.

### File Headers

Each file requires a minimal header containing:

-   File path
-   Project name
-   Creation date and author
-   Copyright/license information if applicable
-   Brief description for complex components

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

Properties and methods should be organized into logical groups using regular comments:

```swift
// Dependencies
private let logger = AppLogger.capture
private let windowManager: WindowManager

// Private State
private var isCapturing: Bool = false
private var sourceObserver: NSObjectProtocol?

// Published State
@Published private(set) var isSourceAppFocused: Bool = false
@Published private(set) var sourceWindowTitle: String?

// Preview Settings
@Default(.captureFrameRate) private var captureFrameRate

// Actions
func startCapture() {
    // Implementation
}
```

Use `// MARK: -` comments only for major section breaks in larger files:

```swift
// MARK: - Private Methods

private func validateWindow(_ window: NSWindow) -> Bool {
    window.contentView != nil && window.frame.size.width > 0
}
```

### Type Documentation

Only document complex types that require explanation of their responsibilities or special usage notes. Simple types don't need documentation.

Example:

```swift
/// Manages the lifecycle and processing of screen capture streams,
/// handling frame processing, error handling, and state synchronization.
class CaptureEngine: NSObject, @unchecked Sendable {
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
private let logger = AppLogger.shortcuts   // For keyboard shortcut functionality
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

### Error Logging

Always use `logError` for error conditions, providing context when available:

```swift
logger.logError(error, context: "Failed to update stream configuration")
```

For error messages without an Error object, use `error`:

```swift
logger.error("Missing content scale in attachments")
```

### Logging Best Practices

1. **Be Selective**: Log meaningful state changes and operations, not routine method calls
2. **Use Debug Level**: For detailed information needed during development
3. **Include Context**: Log relevant identifiers and values that aid troubleshooting
4. **Performance**: Avoid logging in tight loops or high-frequency operations

### Examples of Good Logging

```swift
// State changes
logger.info("Window opacity updated to \(Int(windowOpacity * 100))%")

// Operation results
logger.info("Retrieved \(filteredWindows.count) windows for binding")

// Initialization
logger.debug("Initializing capture services")

// Error with context
logger.logError(error, context: "Failed to update stream configuration")

// Direct error message
logger.error("Invalid window state detected")
```
