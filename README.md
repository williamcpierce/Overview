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

Switch to source applications through preview clicks or keyboard shortcuts

### Preview Customization

Customize preview window appearance, visibility, and saving/restoration

### Glanceable Overlays

Display source app names, window titles, and focus status

## System Requirements

-   macOS Ventura (13.0) or later
-   Screen Recording permission (required for window capture)

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

See setting menu info panels for full details

-   Preview
    -   Frame Rate
    -   Automatic Hiding
        -   Hide previews for inactive source applications
        -   Hide preview for focused source window
-   Windows
    -   Appearance
        -   Opacity
        -   Shadows
        -   Default dimensions
    -   Visibility
        -   Show windows in Mission Control
        -   Show windows on all desktops (including fullscreen)
    -   Management
        -   Create window on launch
        -   Close window with preview source
        -   Save window positions on quit
-   Overlays
    -   Window Focus
        -   Border width
        -   Border color
    -   Source Title
        -   Font size
        -   Background opacity
        -   Location
        -   Type (window, application, or both)
-   Shortcuts
    -   Window Activation
        -   Keyboard shortcuts for focusing windows
        -   Multiple window titles per shortcut for window cycling
-   Sources
    -   Source App Filter
        -   Window source list filtering
        -   Filter mode (blocklist/allowlist)
-   Updates
    -   Automatically check for updates
    -   Automatically download updates
    -   Enable beta updates

## Privacy & Security

Overview requires Screen Recording permission to function, but:

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
