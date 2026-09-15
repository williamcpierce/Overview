# Overview Dev

Overview Dev is a personal Apple-silicon, macOS 27 preview companion for two to four EVE clients. It keeps live ScreenCaptureKit previews, restores client assignments, switches clients by click or shortcut, and labels paused or disconnected captures.

This fork uses the independent bundle identifier `local.chriswilliamson.OverviewDev`. It has no update feed, donation action, or upstream support action.

## Requirements

- macOS 27 on Apple silicon
- Xcode 27
- Screen Recording permission
- Optional Accessibility permission for exact-window activation and focus tracking

## Build and test

Run the deterministic core tests:

```sh
swift test
```

Build the app with local ad-hoc signing into a repository-local Derived Data directory:

```sh
xcodebuild \
  -project Overview.xcodeproj \
  -scheme Overview \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$PWD/.derivedData" \
  build
```

For a compile-only verification that does not sign:

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

Install the personal build at the consistent local path `/Applications/Overview Dev.app`:

```sh
ditto \
  "$PWD/.derivedData/Build/Products/Debug/Overview Dev.app" \
  "/Applications/Overview Dev.app"
```

## Features in this fork

- Reliable ScreenCaptureKit capture lifecycle with clear paused / reconnecting / permission / failed states.
- Restored preview assignments and layouts (versioned storage; legacy geometry migrates).
- **EVE-only sources:** pickers list only CCP EVE Online windows (`com.ccpgames.*`, or app name EVE Online / EVE Launcher).
- **Source groups:** one preview can own Main + Scout and swap on focus; keep Titan on a separate always-visible preview.
- Edit-mode move/resize with optional aspect lock; overlays stay out of the drag path.
- **Spaces / fullscreen:** Settings → Windows → **Show on all Spaces / fullscreen** so previews can sit on a display running a fullscreen game (uses `canJoinAllSpaces` + `fullScreenAuxiliary`).

See [PLAN.md](PLAN.md) for completed work and what is still manual.

## First run

1. Launch `/Applications/Overview Dev.app`.
2. Grant Screen Recording permission when prompted.
3. Create a preview with `⌘N` and select an EVE window.
4. For Main + Scout swap: right-click the preview → **Manage Source Group…** and select both clients (swap is automatic for multi-source groups).
5. For Titan: keep a separate preview with Titan only and leave **Hide When Focused** off.
6. Turn on **Show on all Spaces / fullscreen** if you drag previews onto a fullscreen-game display.
7. Use **Help → Enable Exact Window Focus…** if exact focus tracking is wanted.
8. Use edit mode to move or resize previews; saved previews and layouts retain source groups.

For fewer Screen Recording / Accessibility re-prompts after rebuilds, use Xcode **Automatically manage signing** with a Personal Team instead of ad-hoc signing.

Window image data stays local and is neither stored nor transmitted.

## Live validation (still manual)

The automated suite covers capture startup, cancellation, retry exhaustion, explicit stop, permission coalescing and revocation, source matching, EVE-only source matcher, legacy storage migration, display clamping, shortcut cycling, and source-group migration/selection.

Hardware-dependent validation still requires running two and four live EVE clients:

- Click and shortcut switching, application-only and exact-window focus indicators, client closure/relaunch, and layout restoration.
- Source-group swap (Main/Scout) plus always-visible Titan; edit-mode drag across monitors onto a fullscreen client.
- Resize, Hide All/show, sleep/wake, Spaces, fullscreen, and connected/disconnected display configurations.
- Accessibility granted and denied.
- A 60-minute four-client session checking crashes, stream accumulation, memory growth, stale-frame labels, and capture resource release.
- CPU, memory, and frame delivery compared with the upstream build at identical preview sizes and frame rates.

## License and attribution

This project remains MIT licensed; see [LICENSE.md](LICENSE.md).

Overview was created by William Pierce. Its design and purpose were inspired by [EVE-O Preview](https://github.com/Proopai/eve-o-preview), originally developed by StinkRay and maintained by Dal Shooth and Devilen. Capture frame extraction includes code derived from Apple’s MIT-licensed ScreenRecorder sample.
