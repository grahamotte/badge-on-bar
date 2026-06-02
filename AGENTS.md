# Badge on Bar Agent Guide

## Product Goal

Badge on Bar monitors app badge counts from the Dock and surfaces them in the macOS menu bar. The app runs as a menu bar accessory with no Dock icon and no main window. It uses the macOS Accessibility API to read badge labels from running apps and displays matching menu bar items.

This is a modern, native SwiftUI rewrite of [Doll](https://github.com/xiaogdgenuine/Doll).

## UX

- The app lives primarily in the menu bar. When no window is open, there is no Dock icon (`LSUIElement = YES`, `.accessory` activation policy). When the config window opens, the activation policy switches to `.regular` so the app appears in the Dock and can become the foreground app.
- A configuration window opens automatically on first launch. After that, right-click or Option-click any monitored app's menu bar item to reopen it.
- Each monitored app gets its own icon + badge in the menu bar.
- Left-click a monitored app's menu bar item to open that app. Right-click or Option-click to open the configuration window.
- Accessibility permission is required; the app prompts the user on first launch.

## File Layout

```
BadgeOnBar/
  BadgeOnBarApp.swift        -- @main App entry point + AppDelegate
  AppBadgeInfo.swift         -- Shared data model (bundleID, name, icon)
  BadgeMonitor.swift         -- Dock AX polling, badge reading, element tree walking
  StatusBarManager.swift     -- Per-app NSStatusItem lifecycle, click handling
  ConfigurationView.swift    -- SwiftUI config window (sidebar + detail)
  AppSettings.swift          -- UserDefaults-backed monitored app set
  PermissionsManager.swift   -- Accessibility permission check + prompt
  Info.plist                 -- NSAccessibilityUsageDescription
  Assets.xcassets/           -- App icon, accent color
```

Xcode uses `PBXFileSystemSynchronizedRootGroup` (objectVersion 77). New `.swift` files added to `BadgeOnBar/` are auto-discovered — no `project.pbxproj` changes needed.

## Architecture

Four concerns, each in its own file:

### Badge Monitor (`BadgeMonitor.swift`)

Reads badge counts from the Dock process (`com.apple.dock`) using the macOS Accessibility API.

- Walks the Dock's accessibility element tree to find app entries by `AXTitle`.
- Reads badge text from each entry's `AXStatusLabel` attribute.
- Polls every 1 second via `Timer`. The Accessibility API cannot observe attribute value changes — only element add/remove events.
- Uses `AXObserver` for `kAXCreatedNotification` / `kAXUIElementDestroyedNotification` to detect when Dock entries change.
- Exposes `@Observable` properties (`badges`, `availableApps`, `dockApps`) for SwiftUI consumption.
- Provides an `onUpdate` callback closure for AppKit consumers (StatusBarManager).
- Resolves Dock titles to bundle IDs via a multi-step fallback: AXFilename/URL → running app lookup → bundle name matching → installed app registry.
- Builds an installed app registry from `/Applications`, `/System/Applications`, `~/Applications` for fallback resolution.

There is no modern alternative to the Accessibility API for this. No other framework (NotificationCenter, App Intents, NSWorkspace) exposes another app's Dock badge data.

### Status Bar (`StatusBarManager.swift`)

Manages one `NSStatusItem` per monitored app. Cannot use SwiftUI `MenuBarExtra` because that API only supports a single item.

- Creates/destroys `NSStatusItem` instances as apps are added/removed from monitoring.
- Each item gets a unique `autosaveName = "BadgeOnBar_<bundleID>"` (mandatory — see Gotchas).
- Renders app icon + red badge text on each button via `NSAttributedString`.
- Handles left-click (open app) vs right-click / Option-click (open config window via `onShowConfig` closure).
- Syncs from both `monitor.onUpdate` and `settings.onChanged` callbacks.
- Uses direct `NSImage(size:flipped:drawingHandler:)` for icon resizing (no TIFF round-trip — see Gotchas).

### Configuration Window (`ConfigurationView.swift`)

SwiftUI `NavigationSplitView` for managing which apps to monitor.

- **Sidebar**: Lists apps currently on the Dock. Each row has an app icon, name, running status, and a toggle switch.
- **Detail**: Shows selected app details and monitoring toggle.
- **Accessibility setup**: Full-screen prompt when permission is not granted, with a button to open System Settings. Polls `AXIsProcessTrusted()` every 1s to auto-advance.
- **Welcome view**: Empty-state messaging when no app is selected.

App listing combines `monitor.dockApps` (apps on Dock) with `settings.monitoredBundleIDs` (persisted selections) to show monitored apps even when not on the Dock.

### Settings (`AppSettings.swift`)

- `@Observable @MainActor` class storing `Set<String>` of monitored bundle IDs.
- Persisted to `UserDefaults` under `"monitoredBundleIDs"`.
- Exposes an `onChanged` callback for AppKit consumers.

### Permissions (`PermissionsManager.swift`)

- Static enum with `isTrusted`, `checkOrPrompt()`, and `openSettings()`.
- `checkOrPrompt()` is called once on launch — it shows the system prompt if not already trusted.
- `openSettings()` opens System Settings > Privacy > Accessibility.

## Data Flow

```
BadgeMonitor (@Observable)                 AppSettings (@Observable)
  ├─ badges: [String: Int]                   ├─ monitoredBundleIDs: Set<String>
  ├─ availableApps: [AppBadgeInfo]           └─ onChanged: callback
  ├─ dockApps: [AppBadgeInfo]
  └─ onUpdate: callback
       │                                           │
       │     ┌─────────────────────────────────────┘
       ▼     ▼
  StatusBarManager (AppKit)
    ├─ sync(): creates/updates/removes NSStatusItems
    ├─ clicked(): left → open app, right/opt → show config
    └─ onShowConfig: callback → AppDelegate.showConfigWindow()
       │
       ▼
  ConfigurationView (SwiftUI)
    ├─ @Environment(AppSettings.self)  → read monitoredBundleIDs
    ├─ @Environment(BadgeMonitor.self) → read dockApps, availableApps
    └─ Toggle writes → AppSettings.setMonitored()
```

**Pattern note**: SwiftUI views use `@Environment` with `@Observable`. AppKit code (StatusBarManager) uses callback closures (`onUpdate`, `onChanged`, `onShowConfig`) because `@Observable` observation is SwiftUI-only.

## Technical Defaults

- Use Swift for implementation.
- Use SwiftUI for UI and AppKit (`NSStatusItem`, `AXUIElement`) only when required.
- Target the latest stable macOS major version.
- Strongly prefer native window and control styling.
- The app entry point uses `@main App` with `NSApplicationDelegate` for status bar lifecycle management.
- The activation policy is `.accessory` when no window is open. Switch to `.regular` (and call `NSApp.activate(ignoringOtherApps: true)`) when showing the config window, and back to `.accessory` when the window closes.

## Workflow

- Keep monitor logic, menu bar display, configuration UI, and permission handling as separate files.
- Xcode auto-discovers new Swift files via `PBXFileSystemSynchronizedRootGroup` — no need to touch `project.pbxproj`.
- After code changes, run `mise build` and report result.

## Collaboration

- Call out incorrect assumptions about macOS, Swift, SwiftUI.
- Keep recommendations practical and biased toward momentum.
- Choose options that feel native, simple, and easy to evolve.
- Ignore Doll's settings UI — it sucks and should not be used as a reference. However, Doll's main app code (badge monitoring, status bar management, permissions) is a useful implementation reference. The Doll source is available as a git submodule at `Doll/`.

## Gotchas

### NSStatusItem.autosaveName is mandatory

When managing multiple `NSStatusItem` instances, each one **must** have a unique `autosaveName`. Without it, macOS cannot distinguish between items and will silently reuse, reorder, or remove them when you create/destroy other items. This manifests as "removing one app's toggle deletes a different app from the menu bar."

```swift
// REQUIRED — without this, items collide
item.autosaveName = "BadgeOnBar_\(bundleID)"
```

Doll does the same: `statusItem.autosaveName = "Doll_\(app.bundleId)"`. Do not skip this.

### Do not call removeStatusItem and statusItem(withLength:) in deferred/dispatched blocks

These must be called on the same run-loop cycle or macOS layout breaks. No `DispatchQueue.main.async` wrappers, no deferred creation passes. Remove old items and create new items synchronously in one pass.

### NSImage.tiffRepresentation can silently return nil

When resizing icons for the menu bar, do not round-trip through TIFF. Some app icons (PDF-based, certain color profiles) will fail the TIFF conversion, producing a nil image and an invisible menu bar item. Draw directly into a new `NSImage(size:)` instead.

### App activation policy toggles between .accessory and .regular

When no window is open, the activation policy must be `.accessory` so the app has no Dock icon (a pure menu bar accessory). When showing the config window, switch to `.regular` and call `NSApp.activate(ignoringOtherApps: true)` so the app gets a Dock icon and its menu bar appears while the window is in focus. Switch back to `.accessory` when the window is closed (`windowShouldClose`).

```swift
func showConfigWindow() {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    // ... show window
}

func windowShouldClose(_ sender: NSWindow) -> Bool {
    sender.orderOut(nil)
    NSApp.setActivationPolicy(.accessory)
    return false
}
```

Do not leave the app in `.regular` after the window closes — it leaves a stale Dock icon.
