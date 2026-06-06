# Badge on Bar Agent Guide

Write as little code as possible. Prefer small, native changes that preserve the current architecture.

## Product Goal

Badge on Bar reads other apps' Dock badge counts with the macOS Accessibility API and mirrors selected badges into separate menu bar items. It is a menu bar accessory by default: no Dock icon, no main window unless configuration is open.

This is a modern native SwiftUI/AppKit rewrite of Doll. Doll's monitoring/status-bar code is useful reference material in `Doll/`; Doll's settings UI is not.

## Current Architecture

Keep the app split across these concerns:

```
BadgeOnBar/BadgeOnBar/
  BadgeOnBarApp.swift        @main App, AppDelegate, config window lifecycle
  AppBadgeInfo.swift         Bundle ID/name/icon model and bundle lookup
  BadgeMonitor.swift         Dock AX polling, badge reading, app discovery
  StatusBarManager.swift     NSStatusItem lifecycle, click handling, rendering
  ConfigurationView.swift    SwiftUI settings/config window
  AppSettings.swift          UserDefaults-backed settings and per-app overrides
  PermissionsManager.swift   Accessibility trust prompt/settings link
  question.png               Question-mark display mode asset
```

Xcode uses `PBXFileSystemSynchronizedRootGroup` (`objectVersion 77`). New Swift files under `BadgeOnBar/BadgeOnBar/` are auto-discovered; do not touch `project.pbxproj` just to add a file.

## Data Flow

```
BadgeMonitor (@Observable)                   AppSettings (@Observable)
  badges: [bundleID: count]                    monitoredBundleIDs
  availableApps: running regular apps          defaults + per-app overrides
  dockApps: Dock apps                          startAtLogin
  installedApps: /Applications registry        onChanged callback
  onUpdate callback
            │                                      │
            └──────────────┬───────────────────────┘
                           ▼
                StatusBarManager (AppKit)
                  creates/removes/updates one NSStatusItem per visible app
                  opens app on left click
                  opens config on right click or Option-click
                           │
                           ▼
                AppDelegate.showConfigWindow()

ConfigurationView reads AppSettings and BadgeMonitor through SwiftUI @Environment.
```

Pattern: SwiftUI observes `@Observable` values through `@Environment`. AppKit uses simple callbacks (`monitor.onUpdate`, `settings.onChanged`, `statusBarManager.onShowConfig`).

## BadgeMonitor Pattern

`BadgeMonitor` is `@MainActor @Observable`.

- Only start when `PermissionsManager.isTrusted` is true.
- Build `installedApps` once on start from `/Applications`, `/System/Applications`, and `~/Applications`.
- Track running regular apps in `availableApps`.
- Flatten the Dock AX tree, resolve Dock entries to bundle IDs, and cache the matching `AXUIElement`s in `dockAppElements`.
- Read badge text from `AXStatusLabel`. Integer text becomes the badge count; non-empty non-integer text becomes `-1`.
- Poll every 1 second. The Accessibility API does not notify badge-value changes.
- Use `AXObserver` only for Dock element creation/destruction and trigger a Dock reload.
- Use `NSWorkspace.didLaunchApplicationNotification` and `.didTerminateApplicationNotification` for full refreshes.

Bundle ID resolution order matters:

1. `AXFilename` / `AXURL`
2. matching running app name
3. running app bundle display/name lookup
4. installed app registry fallback

There is no modern framework replacement for this. NotificationCenter, App Intents, NSWorkspace, and SwiftUI do not expose other apps' Dock badge values.

## StatusBarManager Pattern

`StatusBarManager` is `@MainActor` AppKit glue. Keep it out of SwiftUI.

- Manage one `NSStatusItem` per visible monitored bundle ID.
- Visibility is `monitoredBundleIDs` filtered by `zeroBehavior`: `.hide` removes zero-badge items.
- Badge source is `settings.demoBadgeOverride ?? monitor.badges[bundleID] ?? 0`.
- Create/remove status items synchronously inside `sync()`.
- Set `item.autosaveName = "BadgeOnBar_\(bundleID)"` for every item.
- Button clicks: left opens the app; right click or Option-click opens config.
- Render button image from app icon, SF Symbol override, or `question.png` depending on settings.
- Render badge overlay as a subview tagged with `badgeViewTag`; remove the old overlay before adding a new one.
- Resize icons by drawing into `NSImage(size:flipped:drawingHandler:)`. Do not use TIFF round-trips.

Display semantics:

- `DisplayMode.badge`: numeric badge up to `99`; non-integer badge (`-1`) becomes a centered dot.
- `DisplayMode.dot`: small corner dot for positive or `-1` badges.
- `DisplayMode.question`: uses `question.png` as the icon and no overlay when badge is non-zero.
- `ZeroBehavior.show`: show normal icon at zero.
- `ZeroBehavior.greyscale`: show greyscale icon at zero.
- `ZeroBehavior.hide`: remove status item at zero.

## AppSettings Pattern

`AppSettings` is the single source of truth for user config. Keep persistence here.

Current settings:

- `monitoredBundleIDs`
- `startAtLogin` through `SMAppService.mainApp`
- `demoBadgeOverride`, temporary and non-persisted
- default + per-app `DisplayMode`
- default + per-app `BadgeColorOption`
- default + per-app `ZeroBehavior`
- per-app SF Symbol overrides

When monitoring is enabled for an app, seed per-app display/color/zero overrides from the current defaults. When monitoring is disabled, remove that app's overrides and symbol override.

Preserve the migration shims for old dot-badge defaults/overrides unless there is an explicit migration cleanup task.

Every settings mutator that affects status-bar output must call `onChanged?()`.

## ConfigurationView Pattern

The config window is SwiftUI and should stay native, compact, and settings-first.

- Use `NavigationSplitView`.
- Sidebar sections: `Settings`, `Apps on Dock`, expandable `Other Apps`.
- Detail defaults to General settings.
- App list combines `monitor.dockApps`, `monitor.installedApps`, and monitored apps that are no longer on the Dock.
- Accessibility setup replaces the main UI when trust is missing and polls trust every second.
- Use small native controls: switches, segmented pickers, color swatches, and icon grid buttons.
- Keep helper views private in `ConfigurationView.swift` unless reuse forces extraction.

Do not add a landing page, marketing copy, or custom visual theme. This is a utility config window.

## App Lifecycle Pattern

`BadgeOnBarApp` owns the SwiftUI `Window`; `AppDelegate` owns lifecycle glue.

- `applicationWillFinishLaunching`: set `.accessory`.
- `applicationDidFinishLaunching`: create `StatusBarManager`, wire callbacks, start monitor, prompt permissions, attach window delegate.
- `showConfigWindow()`: set `.regular`, activate, then bring the config window forward.
- `windowShouldClose`: order the config window out, set `.accessory`, and return `false`.
- `applicationShouldTerminateAfterLastWindowClosed`: `false`.
- `applicationWillTerminate`: stop monitor.

Do not leave the app in `.regular` after the config window closes.

## Technical Defaults

- Swift + SwiftUI for UI; AppKit only where macOS requires it (`NSStatusItem`, app/window lifecycle, Accessibility).
- Keep classes that touch UI or AX state on `@MainActor`.
- Prefer native macOS controls and styling.
- Keep implementation in the existing files unless a new concern clearly earns its own file.
- Add small private helpers before broad abstractions.
- Avoid dependencies. This app should remain tiny.

## Gotchas

### `NSStatusItem.autosaveName` is mandatory

Without a unique autosave name, macOS can reuse, reorder, or remove the wrong item.

```swift
item.autosaveName = "BadgeOnBar_\(bundleID)"
```

### Create and remove status items synchronously

Do not wrap `removeStatusItem` or `statusItem(withLength:)` in deferred/dispatched blocks. Removing old items and creating new items must happen in the same `sync()` pass.

### Avoid `NSImage.tiffRepresentation`

Some app icons fail TIFF conversion. Resize by drawing directly into a new `NSImage`.

### Permission changes must restart/stop monitoring

When Accessibility trust flips in `ConfigurationView`, call `monitor.start()` or `monitor.stop()` through the existing `updateTrust` path.

### `-1` is a meaningful badge value

`-1` means Dock exposed a non-empty, non-integer badge label. Keep it distinct from zero.

## Workflow

- Check `git status` before editing.
- Preserve user changes. Never revert unrelated work.
- After code changes, run `mise build` and report the result.
- For doc-only changes, `mise build` is optional, but run it if the user asks to lock in architecture or verify the repo state.
- Keep recommendations practical and biased toward momentum.
