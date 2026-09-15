# Overview Dev — plan and status

## Summary

Personal Apple-silicon, macOS 27 preview companion for **2–4 EVE clients**: live ScreenCaptureKit previews, restored assignments, click/shortcut switching, and clear paused/disconnected labels.

Fork identity: `local.chriswilliamson.OverviewDev`. No Sparkle update feed, donation action, or upstream support action.

## Phase 1 — core reliability (done)

- Independent bundle, local signing path, Sparkle/funding/support surface removed.
- Explicit capture lifecycle (`idle` → `starting` → `running` / `paused` / `reconnecting` / permission / `failed`); serialized start/stop; bounded newest-frame buffer; sleep and Hide All suspend/resume.
- Shared source inventory; versioned saved previews with `SourceIdentity`; legacy geometry migration; display clamping.
- Optional Accessibility for exact-window focus; app-level fallback when denied.
- Automated tests under `Tests/OverviewCoreTests/` (`swift test`); README build/install instructions.

## EVE-only sources (done)

Preview, source-group, and shortcut pickers only list EVE Online clients:

- Bundle ID prefix `com.ccpgames.*`, or application name `EVE Online` / `EVE Launcher`.
- Implemented via `EveSourceMatcher` + `SourceFilterService`; generic allowlist/blocklist UI removed.
- Full inventory remains available for focus/identity resolve; filtered lists feed pickers only.

## Source groups (done)

Addresses stacked Main + Scout + always-visible Titan without relying on a global “hide focused source” toggle.

- Each preview stores `sources: [SourceIdentity]` plus per-window `hideWhenFocused`.
- Legacy single-`source` saves migrate into a one-member group.
- Multi-source (2+) groups always swap: click/focus shows the inactive member and hides the focused one.
- Single-source (e.g. Titan) keeps optional Hide When Focused.
- Optimistic local focus on preview click so the wrong client is not left visible.
- UI: right-click / edit → **Manage Source Group…**; global hide setting removed from Previews settings.

## Preview UX hardening (done)

- Edit-mode drag: empty picker no longer blocks move; overlays are corner-hit; thinner `WindowAccessor` sync while dragging.
- Aspect lock via `contentAspectRatio` when sync-aspect is on and a source is assigned; snap once; do not fight live resize.
- Transient capture states keep the last frame; Retry/Choose Source only for fail / permission / waiting — not every `.starting` / `.reconnecting`.
- Brand-new empty windows are not auto-closed on capture stop (`hadAssignment` tracking).
- Window services that touch `NSWindow` are `@MainActor` for macOS 27 concurrency.

## Spaces / fullscreen overlays (done)

Fullscreen games own a separate Space. Previews need both `.canJoinAllSpaces` and `.fullScreenAuxiliary`.

- Setting **Show on all Spaces / fullscreen** (default on for new installs) applies both behaviors at window creation and when the setting changes.
- Without that setting, dragging onto a display running a fullscreen client will still fail.

## Signing and permissions (operator note)

TCC (Screen Recording / Accessibility) cannot be auto-granted. Ad-hoc `CODE_SIGN_IDENTITY = "-"` often re-prompts after rebuilds. Prefer **Automatically manage signing** with a Personal Team so the same team identity sticks across installs.

## Still manual / deferred

- Live validation with 2 and 4 EVE clients (see README “Phase 1 live validation”).
- Public distribution, notarization, automatic updates, visual redesign, App Intents, HDR.
- Whole-project Swift 6 migration.

## Deliverable checklist

- [x] Locally buildable personal app + `swift test`
- [x] Capture reliability, source restore, source groups
- [x] EVE-only source pickers
- [x] Fullscreen-space overlay participation
- [ ] Hardware validation report for remaining live EVE scenarios
