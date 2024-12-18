# Swift Code Documentation Standards

This guide prioritizes self-documenting code through clear naming, strong types, and proper code organization. Documentation should focus on high-level architecture and APIs rather than implementation details.

## Code Organization Principles

Structure your code using clear type and function names that express intent:

```swift
// Instead of commenting what a property does:
// The scale factor for display
private let displayScale: CGFloat

// Use a clear type and name:
private let displayDensityScaleFactor: CGFloat

// Instead of commenting workflow:
// First check if window exists, then capture
func captureWindow() { ... }

// Create a well-named function:
func validateAndCaptureSelectedWindow() { ... }
```

## API Documentation

Document public APIs that form contracts with other parts of the system. Focus on behavior and guarantees rather than implementation:

```swift
/// Guarantees thread-safe access to capture configuration.
/// Consumers must call stopCapture() before modifying settings.
protocol CaptureConfigurable {
    var isCapturing: Bool { get }
    func stopCapture() async throws
    func updateConfiguration(_ config: CaptureConfig) async throws
}
```

## Type Safety Over Comments

Use Swift's type system to enforce constraints instead of documenting them:

```swift
// Instead of:
/// ID must be non-empty string
var id: String

// Use:
struct ID: RawRepresentable {
    let rawValue: String
    init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }
}
var id: ID
```

## Error Handling

Use descriptive error types instead of comments:

```swift
// Instead of:
/// Throws when window isn't selected or stream fails
func startCapture() throws

// Use:
enum CaptureError: Error {
    case noWindowSelected
    case streamInitializationFailed(underlying: Error)
    case invalidConfiguration(reason: String)
}
func startCapture() throws CaptureError
```

## Required Documentation

Only document when code alone cannot convey:

1. Performance implications:

```swift
/// Caches transformed frames to maintain 60fps on memory-constrained devices
final class FrameTransformCache { ... }
```

2. Threading requirements:

```swift
/// Thread-confined type - must be instantiated and accessed from the same thread
final class DisplayLinkCoordinator { ... }
```

3. Mathematical algorithms or external specifications:

```swift
/// Implements color space conversion per ICC.1:2022 specification
/// https://www.color.org/specification/ICC.1-2022.pdf
struct ColorSpaceConverter { ... }
```

## File Organization

Instead of using comment markers, organize code through file structure:

1. Break large files into focused types
2. Use extensions to group related functionality
3. Follow a consistent property/method organization
4. Create dedicated types for major functionality groups

Example:

```swift
// Instead of MARK comments:
final class CaptureEngine {
    // Properties
    private let config: CaptureConfig

    // Public interface
    func startCapture() { ... }

    // Implementation details in extension
}

extension CaptureEngine: CaptureConfigurable {
    // Protocol conformance
}
```

## Legacy Code Markers

Only use these comment types when absolutely necessary:

```swift
// WARNING: Threading violation risks - planned for refactor in Q2 2024
// TODO: [ARCH-123] Replace with native metal compute shader when available
```

## Key Principles

1. Write self-documenting code through clear naming and strong types
2. Document APIs and architectural boundaries, not implementations
3. Use the type system to enforce constraints
4. Break complex code into well-named smaller pieces
5. Keep documentation close to the code it describes
6. Only document what code cannot express
7. Focus documentation on "why" not "what"

## Remember

-   If you feel the need to add a comment, first try to make the code more expressive
-   Documentation should focus on architectural relationships and API contracts
-   Use Swift's type system to prevent errors instead of commenting about them
-   Break complex logic into well-named functions instead of explaining with comments
-   Keep any necessary documentation updated when code changes
