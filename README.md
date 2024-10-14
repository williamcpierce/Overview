# Overview: Window Previews on macOS

## Alpha Release

**Note: Overview is alpha software. It is not yet feature-complete and may contain bugs or unexpected behavior. Use at your own risk.**

## Overview

Overview is a macOS app that allows you to create floating, semi-transparent windows that display live previews of other application windows. It's perfect for keeping an eye on background tasks, monitoring video streams, or maintaining visual context while working across multiple apps.

## Features

- **Live Window Previews:** Capture and display real-time previews of any window on your Mac.
- **Multi-Window Support:** Create multiple Overview windows to monitor several applications simultaneously.
- **Bring to Front:** Quickly switch to the source window with a single click.
- **Floating Windows:** Overview windows stay on top of other applications for constant visibility.
- **Context Menu:** Right-click on Overview windows to access additional options.
- **Customizable Opacity:** Adjust the transparency of Overview windows to suit your workflow.
- **Adjustable Frame Rate:** Set the refresh rate of previews to balance performance and system resources.

## System Requirements

- macOS Sonoma (macOS 14) or later
- Apple Silicon

## Installation

1. Download the lastest version from GitHub [Releases](https://github.com/williamcpierce/Overview/releases).
2. Mount the disk image and drag Overview into your Applications folder.

### On First Launch
- The app package is *unsigned* at this stage of development. Follow instructions [here](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) for your macOS version to run the application.  
- There will be an error and a notification to allow screen recording. This is necessary to show the preview windows. Allow screen recording permission in settings and then re-launch Overview. 

## Usage

1. Launch Overview
2. Select a window to capture from the available windows list
3. Toggle Edit Mode (via the window context menu) to reposition or resize Overview windows
4. Click on an Overview window (with Edit Mode disabled) to switch to the previewed application
5. Create new Overview windows with ⌘N while in Edit Mode, or via the File menu
6. Adjust settings for opacity, frame rate, and default window size in the Settings menu

### Settings

- Window opacity
- Preview frame rate
- Default window size for new Overview windows

## Acknowledgements

The design, features, and general purpose of Overview is heavily inspired by [Eve-O Preview](https://github.com/Proopai/eve-o-preview). 
Eve-O Preview was originally developed by StinkRay, and is currently maintained by Dal Shooth and Devilen. 

## Known Issues

- Unexpected behavior while Stage Manager is enabled
- Only windows in the current space appear in the the selection menu
- Resizing a window will not change the aspect ratio of the Overview window
- Multiple windows from an application can be previewed, but clicking brings the application into focus, not a specific window
- Performance is suboptimal
- For the complete list of known issues, see [github.com/williamcpierce/Overview/issues](https://github.com/williamcpierce/Overview/issues?q=is%3Aopen+is%3Aissue+label%3Abug)

## Contributing

Contributions to Overview are welcome, but as the project is in its early stages, please contact me to coordinate before starting any work.

## License

This project is MIT licensed, see the LICENSE file for full details. 

## Disclaimer

Overview is alpha software and is not intended for production use. Use of this software is at your own risk. The developers are not responsible for any data loss or system instability that may occur as a result of using Overview.

## Contact

For all inquiries, email will@williampierce.io
