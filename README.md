# Overview: Window Previews

## Alpha Release

**Note: Overview is currently in an alpha state. It is not yet feature-complete and may contain bugs or unexpected behavior. Use at your own risk.**

## Overview

Overview is an macOS application designed to provide visibility of multiple windows while multitasking. It allows you to create floating preview windows that display live content from other applications. These Overview windows are clickable to instantly jump to the previewed application. 

## Features

- Capture and display live previews of any application in resizable floating windows
- Overview windows are clickable to quickly switch to the corresponding application
- Edit Mode for repositioning and resizing of Overview windows

## System Requirements

- macOS Sonoma (macOS 14) or later
- Apple Silicon

## Installation

You can download the latest dmg from the GitHub Releases page. 

Note the app package is unsigned at this stage of development. Follow instructions at https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac to run the application.  

On first launch, there will be an error and a notification to allow screen recording. This is necessary to show the preview windows. Allow screen recording permission in settings and then re-launch Overview. 

## Usage

1. Launch Overview
2. Select a window to capture from the available windows list
3. Toggle Edit Mode (via the window context menu) to reposition or resize Overview windows
4. Click on an Overview window (with Edit Mode disabled) to switch to the previewed application
5. Create new Overview windows with ⌘+N while in Edit Mode, or via the File menu

## Known Issues

- Only windows in the current space appear in the the selection menu
- Resizing a window will not change the aspect ratio of the Overview window
- Multiple windows from an application can be previewed, but clicking brings the application into focus, not a specific window
- Overview window sizes are not restored when relaunching the application
- Closing an Overview window does not stop the capture of the previewed window
- Closing a previewed application will not close the corresponding Overview window, which will freeze on the last frame
- Performance is suboptimal

## Contributing

Contributions to Overview are welcome! As the project is in its early stages, please contact me before starting any work.

## License

This project is MIT licensed, see the LICENSE file for full details. 

## Disclaimer

Overview is alpha software and is not intended for production use. Use of this software is at your own risk. The developers are not responsible for any data loss or system instability that may occur as a result of using Overview.

## Contact

For all inquiries, email will@williampierce.io
