# Badge on Bar Agent Guide

## Product Goal

Badge on Bar monitors app badge counts from the Dock and surfaces them in the macOS menu bar. The app runs as a menu bar accessory with no Dock icon and no main window. It uses the macOS Accessibility API to read badge labels from running apps and displays matching menu bar items.

This is a modern, native SwiftUI rewrite of [Doll](https://github.com/xiaogdgenuine/Doll).

## UX

- The app lives entirely in the menu bar. No Dock icon (`LSUIElement = YES`), no persistent window.
- A configuration window (opened via the menu bar item) lets the user choose which apps to monitor.
- Each monitored app gets its own icon + badge in the menu bar.
- Left-click a monitored app's menu bar item to open that app. Right-click or Option-click to open the configuration window.
- Accessibility permission is required; the app prompts the user on first launch.

## Architecture

Four concerns, each a separate module or file group:

### Badge Monitor

Reads badge counts from the Dock process (`com.apple.dock`) using the macOS Accessibility API.

- Walks the Dock's accessibility element tree to find app entries by `AXTitle`.
- Reads badge text from each entry's `AXStatusLabel` attribute.
- Polls every 1 second via `Timer`. The Accessibility API cannot observe attribute value changes — only element add/remove events.
- Uses `AXObserver` for `kAXCreatedNotification` / `kAXUIElementDestroyedNotification` to detect when Dock entries change.
- Emits badge values through Combine (`PassthroughSubject`) or `@Observable` for consumption by the status bar layer.

There is no modern alternative to the Accessibility API for this. No other framework (NotificationCenter, App Intents, NSWorkspace) exposes another app's Dock badge data.

### Status Bar

Manages one `NSStatusItem` per monitored app. Cannot use SwiftUI `MenuBarExtra` because that API only supports a single item.

- Creates/destroys `NSStatusItem` instances as apps are added/removed from monitoring.
- Renders the app icon + badge text (or red badge overlay) directly on each button.
- Handles left-click (open app) vs right-click / Option-click (open config window).
- Observes badge updates from the monitor layer and refreshes display.

### Configuration Window

SwiftUI window for managing which apps to monitor and adjusting preferences.

- App picker: search and select from installed apps.
- Monitored app list with per-app settings (giant badge, icon mask, etc).
- Global toggles: launch at login, hide when app not running, show as red badge, etc.
- Presented via a SwiftUI `Window` or `Settings` scene.

### Permissions

- Checks `AXIsProcessTrusted()` on launch.
- If not trusted, prompts via `AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true])`.
- The `NSAccessibilityUsageDescription` in Info.plist explains why access is needed.

## Technical Defaults

- Use Swift for implementation.
- Use SwiftUI for UI and AppKit (`NSStatusItem`, `AXUIElement`) only when required.
- Target the latest stable macOS major version.
- Strongly prefer native window and control styling.
- The app entry point uses `@main App` with `NSApplicationDelegate` for status bar lifecycle management.

## Workflow

- Keep monitor logic, menu bar display, configuration UI, and permission handling as separate concerns.
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
