# Overview: Window Previews on macOS

Overview is a macOS app that creates floating live previews of other application windows, and enables quick switching between them.

![Example Screenshot](https://downloads.williampierce.io/Banner.jpg)

## Beta Release

**Note: Overview is beta software. It may contain bugs or unexpected behavior. Use at your own risk.**

For development updates, please join our Discord:

[![Discord Banner](https://discord.com/api/guilds/1295309622445473865/widget.png?style=banner2)](https://discord.gg/ekKMnejQbA)

## Features

-   Live Window Previews: Real-time window previews with configurable frame rates and automatic hiding
-   Quick App Switching: Switch to source applications through preview clicks or keyboard shortcut bindings
-   Preview Customization: Customize preview window opacity, shadows, dimensions, and behavior
-   Optional Overlays: Overlays show source app names, window titles, and focus status at a glance

## System Requirements

-   macOS Big Sur (13.0) or later
-   Screen Recording permission (required for window capture)

## Installation

1. Download the latest version from the Overview website [williampierce.io/overview/](https://williampierce.io/overview/).
2. Mount the disk image and drag Overview into your Applications folder.

### On First Launch

Grant screen recording permission when prompted

-   Click "Open System Settings" in the permission dialog
-   Enable Overview under Privacy & Security > Screen Recording
-   Relaunch Overview

## Usage

### Quick Start

1. Create a new preview window from the menu bar icon
2. Select a window to capture from the source windows list
3. Enable edit mode via context menu or menu bar icon to move/resize preview windows
4. Close preview windows via context menu

### Controls

-   Left-click preview: Switch to source application
-   Right-click preview: Access context menu
    -   Toggle Edit Mode for repositioning/resizing
    -   Close preview window
-   ⌘N: Create new preview window
-   ⌘,: Open settings

### Settings

-   Previews
    -   Frame rate
    -   Automatic hiding
        -   Hide inactive app previews
        -   Hide active window preview
-   Windows
    -   Appearance
        -   Opacity
        -   Shadows
        -   Default dimensions
    -   Behavior
        -   Show in Mission Control
        -   Create window on launch
        -   Close with preview source
        -   Show windows on all desktops
-   Overlays
    -   Window focus
        -   Border width
        -   Border color
    -   Source title
        -   Font size
        -   Opacity
        -   Location
        -   Type (window, application, both)
-   Shortcuts
    -   Source window activation
-   Sources
    -   Application filtering (blocklist/allowlist)
-   Updates
    -   Automatic update checking
    -   Automatic update downloads

## Known Issues/Limitations

For the complete list of known issues, see [github.com/williamcpierce/Overview/issues](https://github.com/williamcpierce/Overview/issues?q=is%3Aopen+is%3Aissue+label%3Abug)

## Project Funding

Overview is a free and open source project that accepts donations to cover operating expenses (e.g., Apple Developer Program fees, hosting costs, development tools). 100% of donations will be used for project expenses or reinvested in development - no profits will be distributed to any individuals.

Financial operations are managed with full transparency:

-   Complete accounting ledger maintained in [Overview-Finance](https://github.com/williamcpierce/Overview-Finance)
-   Quarterly financial summaries
-   Detailed financial policy available in FUNDING.md

Note: Overview is not registered as a non-profit organization, and donations are not tax-deductible.

To support Overview's development:

-   [GitHub Sponsors](https://github.com/sponsors/williamcpierce) (preferred)
-   [Patreon](https://www.patreon.com/overview_app)

## Development

### Technical Requirements

-   Xcode 15.0
-   Swift 5.0
-   macOS 13.0+ deployment target

### Key Technologies

-   SwiftUI for user interface
-   ScreenCaptureKit for window capture
-   Combine for reactive state management
-   KeyboardShortcuts for shortcut management

### Contributing

Contributions to the codebase are welcome, but as the project is in its early stages, please contact me to coordinate before starting any work.

## Privacy & Security

Overview requires Screen Recording permission to function but:

-   Only captures window content for preview purposes
-   Does not store or transmit window content

## License

This project is MIT licensed, see the LICENSE file for full details.

## Acknowledgments

The design, features, and general purpose of Overview are heavily inspired by [Eve-O Preview](https://github.com/Proopai/eve-o-preview).

Eve-O Preview was originally developed by StinkRay, and is currently maintained by Dal Shooth and Devilen.

Parts of this application include code derived from Apple Inc.'s ScreenRecorder sample code, used under the MIT License.

## Disclaimer

Overview is alpha software and is not intended for production use. Use of this software is at your own risk. The developers are not responsible for any data loss or system instability that may occur as a result of using Overview.
