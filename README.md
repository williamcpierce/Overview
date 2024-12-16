# Overview: Window Previews on macOS

Overview is a macOS app that creates floating live previews of other application windows, and enables quick switching between them.

![Example Screenshot](https://downloads.williampierce.io/GitHub.jpg)

## Alpha Release

**Note: Overview is alpha software. It is not yet feature-complete and may contain bugs or unexpected behavior. Use at your own risk.**

For development updates, please join our Discord:

[![Discord Banner](https://discord.com/api/guilds/1295309622445473865/widget.png?style=banner2)](https://discord.gg/ZFXK5txaVh)

## Features

- Live window previews
- Support for multiple preview windows
- Click preview windows to switch to source application
- Previews float on top of other applications
- Adjustable preview transparency and refresh rate
- Preview overlays:
  - Border highlighting for focused windows
  - Window titles
- Experimental: Hotkey support for application switching

## System Requirements

- macOS Sonoma (macOS 14) or later
- Apple Silicon

## Installation

1. Download the latest version from GitHub [Releases](https://github.com/williamcpierce/Overview/releases).
2. Mount the disk image and drag Overview into your Applications folder.

### On First Launch
- The app package is *unsigned* at this stage of development. Follow instructions [here](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) for your macOS version to run the application.
  - If you aren't comfortable running unsigned apps, you can also clone this project and build it yourself in Xcode 16. 
- There will be an error and a notification to allow screen recording. This is necessary to show the preview windows. Allow screen recording permission in settings and then re-launch Overview. 

## Usage

1. Launch Overview
2. Select a window to capture from the available windows list
3. To reposition or resize preview windows, right click and toggle Edit Mode
4. To close preview windows, right click and select Close Window
5. Left click on preview windows (with Edit Mode disabled) to switch to the previewed application
6. Create new preview windows with ⌘N while in Edit Mode, or via the File menu
7. Adjust preview frame rate, style, and behavior in the Settings menu
8. If you want preview windows to show in all spaces, follow instructions [here](https://support.apple.com/guide/mac-help/work-in-multiple-spaces-mh14112/mac#:~:text=On%20your%20Mac%2C%20Control%2Dclick,app%20opens%20in%20every%20space.)

### Settings

- General:
  - Focused window border overlay
  - Window title overlay
- Previews: 
  - Preview opacity
  - Default preview window size
  - Mission Control visibility
  - Preview alignment help
- Performance:
  - Preview frame rate
- Experimental:
  - Hotkey bindings by window title

## Known Issues/Limitations

- Performance is suboptimal
- Hotkeys only work while Overview is in focus
- Previews will be distorted when using Stage Manager
- Previews cannot float over full-screen applications
- Only windows in the current space appear in the the selection menu

For the complete list of known issues, see [github.com/williamcpierce/Overview/issues](https://github.com/williamcpierce/Overview/issues?q=is%3Aopen+is%3Aissue+label%3Abug)

## Contributing

Contributions to Overview are welcome, but as the project is in its early stages, please contact me to coordinate before starting any work.

## License

This project is MIT licensed, see the LICENSE file for full details. 

## Acknowledgements

The design, features, and general purpose of Overview is heavily inspired by [Eve-O Preview](https://github.com/Proopai/eve-o-preview). 
Eve-O Preview was originally developed by StinkRay, and is currently maintained by Dal Shooth and Devilen. 

## Disclaimer

Overview is alpha software and is not intended for production use. Use of this software is at your own risk. The developers are not responsible for any data loss or system instability that may occur as a result of using Overview.

## Contact

For all inquiries, email will@williampierce.io
