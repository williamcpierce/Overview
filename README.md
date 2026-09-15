# Overview Dev

Personal Apple-silicon preview companion for two to four **EVE Online** clients on macOS 27. Live ScreenCaptureKit previews, restored assignments and layouts, click/shortcut switching, and clear paused or disconnected labels.

- Bundle ID: `local.chriswilliamson.OverviewDev`
- Install path: `/Applications/Overview Dev.app`
- No update feed, donations, or public support channels

Fork of [williamcpierce/Overview](https://github.com/williamcpierce/Overview), maintained privately at [MuninnFPV/Overview](https://github.com/MuninnFPV/Overview).

## Requirements

- macOS 27 on Apple silicon
- Xcode 27
- Screen Recording permission
- Optional Accessibility permission for exact-window activation and focus tracking

## Build and test

```sh
swift test
```

```sh
xcodebuild \
  -project Overview.xcodeproj \
  -scheme Overview \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$PWD/.derivedData" \
  build
```

Compile-only (no signing):

```sh
xcodebuild \
  -project Overview.xcodeproj \
  -scheme Overview \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$PWD/.derivedData" \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Install:

```sh
ditto \
  "$PWD/.derivedData/Build/Products/Debug/Overview Dev.app" \
  "/Applications/Overview Dev.app"
```

For fewer Screen Recording / Accessibility re-prompts after rebuilds, use Xcode **Automatically manage signing** with a Personal Team instead of ad-hoc signing.

## Features

- Capture lifecycle with paused / reconnecting / permission / failed states
- Restored preview assignments and layouts (versioned storage; legacy geometry migrates)
- **EVE-only sources:** pickers list only CCP EVE windows (`com.ccpgames.*`, or app name EVE Online / EVE Launcher)
- **Source groups:** Main + Scout swap in one preview; Titan on a separate always-visible preview
- Edit-mode move/resize with optional aspect lock
- **Spaces / fullscreen:** Settings → Windows → **Show on all Spaces / fullscreen** (`canJoinAllSpaces` + `fullScreenAuxiliary`)

See [PLAN.md](PLAN.md) for status and remaining manual checks.

## First run

1. Launch `/Applications/Overview Dev.app`.
2. Grant Screen Recording when prompted.
3. Create a preview with `⌘N` and select an EVE window.
4. Main + Scout: right-click → **Manage Source Group…** (multi-source groups swap automatically).
5. Titan: separate preview, **Hide When Focused** off.
6. Enable **Show on all Spaces / fullscreen** if dragging onto a fullscreen-game display.
7. Optional: **Help → Enable Exact Window Focus…**
8. Edit mode to place previews; layouts retain source groups.

Window image data stays local and is neither stored nor transmitted.

## License

MIT — see [LICENSE.md](LICENSE.md).

Original Overview by William Pierce. Design inspired by [EVE-O Preview](https://github.com/Proopai/eve-o-preview). Capture frame extraction includes code derived from Apple’s MIT-licensed ScreenRecorder sample.
