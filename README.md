# Overview: Window Previews on macOS

Overview is a macOS app that creates floating live previews of other application windows, and enables quick switching between them.

![Example Screenshot](https://downloads.williampierce.io/Banner.jpg)

## Beta Release

**Note: Overview is beta software. It may contain bugs or unexpected behavior. Use at your own risk.**

For development updates, please join our Discord:

[![Discord Banner](https://discord.com/api/guilds/1295309622445473865/widget.png?style=banner2)](https://discord.gg/ekKMnejQbA)

## Features

### Live Window Previews

Real-time window previews with configurable frame rates and automatic hiding

### Quick App Switching

Switch to source applications through preview clicks or keyboard shortcut bindings

### Preview Customization

Customize preview window opacity, shadows, dimensions, and behavior

### Optional Overlays

Display source app names, window titles, and focus status at a glance

## System Requirements

-   macOS Ventura (13.0) or later
-   Screen Recording permission (required for window capture)
-   Accessibility permission (required for granular window activation)

## Installation

1. Download the latest version from the Overview website [williampierce.io/overview/](https://williampierce.io/overview/).
2. Mount the disk image and drag Overview into your Applications folder.

## Usage

### Quick Start

1. Launch Overview and grant screen recording permission when prompted
2. Create a new preview window from the menu bar icon (⌘N)
3. Select a window to capture from the source windows list
4. Enable edit mode to move/resize preview windows
5. Customize behavior through the settings panel (⌘,)

### Controls

-   Left-click preview: Switch to source application
-   Right-click preview: Access context menu
    -   Toggle Edit Mode for repositioning/resizing
    -   Stop capture
    -   Close preview window
-   `⌘N` Create new preview window
-   `⌘E` Toggle edit mode
-   `⌘,` Open settings

### Settings

See setting menu tooltips for full details

-   Previews
    -   Frame rate configuration
    -   Automatic hiding options
        -   Hide inactive app previews
        -   Hide active window preview
-   Windows
    -   Appearance customization
        -   Opacity
        -   Shadows
        -   Default dimensions
    -   Behavior settings
        -   Show in Mission Control
        -   Create window on launch
        -   Close with preview source
        -   Show windows on all desktops
-   Overlays
    -   Window focus indicators
        -   Border width
        -   Border color
    -   Source title display
        -   Font size
        -   Background opacity
        -   Location
        -   Title type (window, application, or both)
-   Shortcuts
    -   Keyboard shortcuts for window activation
    -   Multiple window titles per shortcut for window cycling
-   Sources
    -   Window source list filtering (blocklist/allowlist)
-   Updates
    -   Automatic update checking
    -   Automatic update downloads
    -   Beta update channel

## Privacy & Security

Overview requires Screen Recording and Accessibility permissions to function, but:

-   Only captures window content for preview purposes
-   Does not store or transmit window content
-   All operations remain local to the device

## Known Issues

For the complete list of known issues, see [github.com/williamcpierce/Overview/issues](https://github.com/williamcpierce/Overview/issues?q=is%3Aopen+is%3Aissue+label%3Abug)

## Project Funding

Support Overview's development:

-   [GitHub Sponsors](https://github.com/sponsors/williamcpierce) (preferred)
-   [Patreon](https://www.patreon.com/overview_app)

100% of donations will be used for project expenses or reinvested in development - no profits will be distributed to any individuals.

See [FUNDING.md](https://github.com/williamcpierce/Overview/blob/main/FUNDING.md) for full details.

## Development

### Technical Requirements

-   Xcode 15.0
-   Swift 5.0
-   macOS 13.0+ deployment target

### Key Technologies

-   SwiftUI for user interface components
-   ScreenCaptureKit for window capture
-   Combine for reactive state management
-   KeyboardShortcuts for global shortcut handling
-   Sparkle for automatic updates

### Coding Standards

The project adheres to a style guide (see [STYLE.md](https://github.com/williamcpierce/Overview/blob/main/STYLE.md)) that emphasizes:

-   Self-documenting code with clear naming
-   Consistent file organization and documentation
-   Structured logging with appropriate levels
-   Clear separation of concerns and modularity

## License

This project is MIT licensed (see [LICENSE.md](https://github.com/williamcpierce/Overview/blob/main/LICENSE.md))

## Acknowledgments

The design, features, and general purpose of Overview are heavily inspired by [Eve-O Preview](https://github.com/Proopai/eve-o-preview).

Eve-O Preview was originally developed by StinkRay, and is currently maintained by Dal Shooth and Devilen.

Parts of this application include code derived from Apple Inc.'s ScreenRecorder sample code, used under the MIT License.
