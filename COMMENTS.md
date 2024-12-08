# Swift Code Commenting Standards

When modifying Swift code in this project, apply the following commenting conventions. The goal is to provide context and clarity while avoiding redundant information.

## File Headers
Every Swift file should begin with:
```swift
/*
 FileName.swift
 Overview

 Created by [Author] on [Date]

 [1-2 sentences describing the file's core responsibility in the app]
*/
```

## Type Documentation
For classes, structs, and enums, document primary purpose and relationships:
```swift
/// Manages [primary responsibility] and coordinates window preview updates
///
/// Key responsibilities:
/// - [Key responsibility 1]
/// - [Key responsibility 2]
///
/// Coordinates with:
/// - [Related component 1]: [Brief interaction description]
/// - [Related component 2]: [Brief interaction description]
```

## Properties
- Only document non-obvious properties
- Focus on explaining "why" not "what"
- Use /// format for property documentation
- Skip documentation for self-explanatory properties

Example:
```swift
/// Scale factor used to maintain preview quality across display densities
private let contentScale: CGFloat

// Clear properties need no documentation:
var isCapturing: Bool
```

## Methods
- Skip documentation for obvious methods (simple getters/setters)
- For complex methods, document:
  - Primary purpose
  - Flow of operations
  - Important side effects
  - Thrown errors
  - Parameter/return value details only if non-obvious

Example:
```swift
/// Initiates window capture with current configuration
///
/// Flow:
/// 1. Validates window selection
/// 2. Configures capture stream
/// 3. Begins frame processing
///
/// - Throws: CaptureError.noWindowSelected if no window is selected
///          CaptureError.captureStreamFailed for stream initialization failures
```

## Code Organization
Always use these MARK sections in order:
```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Delegate Methods (if implementing protocols)
```

## Inline Comments
- Use sparingly
- Focus on explaining non-obvious technical decisions or workarounds
- Format as // with a single space after the slashes

Example:
```swift
// Using CGFloat(exactly:) to handle potential precision loss
let scaledValue = CGFloat(exactly: rawValue) ?? 1.0
```

## Warning Comments
Mark potential issues with consistent format:
```swift
// WARNING: Must be called on main thread
// WARNING: Frame rate changes require stream reconfiguration
```

## TODO Comments
Include issue reference when available:
```swift
// TODO: [Issue#123] Add multiple display support
// TODO: Optimize frame buffer handling
```

## Context Comments for AI/LLM Understanding
Add context about component relationships and system architecture:
```swift
// Context: Coordinates with CaptureEngine for frame synchronization
// and PreviewManager for window selection state
```

## Key Principles
1. Document why, not what (when the code is self-documenting)
2. Avoid redundant comments that restate the code
3. Focus on architectural relationships
4. Use consistent formatting
5. Explain non-obvious technical decisions
6. Document component interactions
7. Keep comments updated when code changes

## Comment Don'ts
1. Don't document obvious properties or methods
2. Don't restate method names in comments
3. Don't add TODO comments without context
4. Don't leave outdated comments
5. Don't describe implementation details unless non-obvious

When updating code, ensure all new code follows these conventions and update existing comments to match these standards when modifying files.