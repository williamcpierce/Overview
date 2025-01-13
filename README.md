# Overview: Window Previews on macOS

Overview is a macOS app that creates floating live previews of other application windows, and enables quick switching between them.

![Example Screenshot](https://downloads.williampierce.io/GitHub.jpg)

## Alpha Release

**Note: Overview is alpha software. It is not yet feature-complete and may contain bugs or unexpected behavior. Use at your own risk.**

For development updates, please join our Discord:

[![Discord Banner](https://discord.com/api/guilds/1295309622445473865/widget.png?style=banner2)](https://discord.gg/ZFXK5txaVh)

## Features

-   Live window previews
-   Quick switching to source applications via preview clicks or customizable hotkeys
-   Adjustable preview window appearance and behavior
-   Overlays for window title and focus status

## System Requirements

-   macOS Big Sur (13.0) or later

## Installation

1. Download the latest version from GitHub [Releases](https://github.com/williamcpierce/Overview/releases).
2. Mount the disk image and drag Overview into your Applications folder.

### On First Launch

-   The app package is _unsigned_ at this stage of development. Follow instructions [here](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) for your macOS version to run the application.
    -   If you aren't comfortable running unsigned apps, you can also clone this project and build it yourself in Xcode 16.
-   Grant screen recording permission when prompted
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
-   Settings (⌘,): Configure preview appearance, behavior, hotkeys, and more

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
-   Overlays
    -   Window focus
        -   Border width
        -   Border color
    -   Source title
        -   Font size
        -   Opacity
-   Hotkeys
    -   Source window activation
-   Sources
    -   Source app filter

If you want preview windows to show in all spaces, follow instructions [here](https://support.apple.com/guide/mac-help/work-in-multiple-spaces-mh14112/mac#:~:text=On%20your%20Mac%2C%20Control%2Dclick,app%20opens%20in%20every%20space.)

## Known Issues/Limitations

-   Performance optimizations in progress
-   Stage Manager compatibility issues (preview distortion)
-   Cannot overlay full-screen applications

For the complete list of known issues, see [github.com/williamcpierce/Overview/issues](https://github.com/williamcpierce/Overview/issues?q=is%3Aopen+is%3Aissue+label%3Abug)

## Contributing

Contributions to Overview are welcome, but as the project is in its early stages, please contact me to coordinate before starting any work.

## License

This project is MIT licensed, see the LICENSE file for full details.

## Acknowledgements

The design, features, and general purpose of Overview are heavily inspired by [Eve-O Preview](https://github.com/Proopai/eve-o-preview).

Eve-O Preview was originally developed by StinkRay, and is currently maintained by Dal Shooth and Devilen.

## Disclaimer

Overview is alpha software and is not intended for production use. Use of this software is at your own risk. The developers are not responsible for any data loss or system instability that may occur as a result of using Overview.

## Contact

For all inquiries, email will@williampierce.io
