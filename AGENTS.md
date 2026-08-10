# AGENTS.md

## Code Moto

This repo is based on Code Moto. Code Moto is a basis/template repository that provides tools and patterns for downstream repositories. From a downstream repository, the basis repository is typically available at `../codemoto.org`. If the current repository is named `codemoto.org`, changes affect the Code Moto framework itself.

Repositories based on Code Moto may omit components or add their own. Backport broadly useful tools and changes to `codemoto.org` when practical.

The "Repo Specific" section blow contains rules specific to this repo only.

## Project Rules

1. Do not introduce bugs or regressions.
2. Before writing code, find analogous code in the repository and follow its established patterns.
3. Do not add comments to code. Preserve existing comments unless they are incorrect or obsolete.
4. Lint, type-check, and test code changes using the tasks defined in the root `mise.toml`.
5. Use root `mise` tasks instead of invoking underlying tools directly when an applicable task exists.
6. Do not create a canvas or visualization unless the user specifically requests one.

## Ruby

- Use `.blank?` and `.present?` for presence checks instead of `.empty?`, `.nil?`, or truthiness checks.
- Do not use `sleep`; use an event- or state-based approach instead.
- Add trailing commas to multiline argument lists and collections.

## TypeScript

- Treat nullable values as both `null` and `undefined`; use `nullish()` in Zod schemas and check for both states.
- Use `pnpm`, not `npm`.
- Use `mise tsc` to type-check.
- Prefer Lodash utilities over custom equivalents when Lodash is already available.
- Use shadcn/ui components.
- Use Tailwind CSS for styling.

## Testing

- Never run network requests, system commands, or application sleeps in tests. Stub those boundaries every time.
- Do not stub other units in a unit test. Only stub network requests, system commands, and sleeps so the real local collaborators and full local surface are exercised together.
- Every business-logic file must have one corresponding unit test file. Source and test files are 1:1.
- Test each business-logic unit thoroughly. Configuration, generated files, framework shells, and other files without business logic do not need tests.
- After every code change, run the whole suite with `mise test`.
- Do not write integration tests.

## File Structure

- `.agents/skills/` - Project-specific agent skills.
- `.env.*` - Environment configuration and secrets. Do not expose secret values.
- `apps/` - Mobile apps for iOS and Android.
- `apps/config.json` - Mobile app release configuration.
- `assets/` - Shared images and media.
- `backend/` - Ruby on Rails API server.
- `deploy/` - Backend, frontend, and mobile app deployment tooling.
- `docs/` - Project documentation in Markdown.
- `frontend/` - React website.
- `frontend/subdomains.json` - Website subdomain configuration.
- `gems/` - Shared Ruby gems.
- `scripts/` - General-purpose scripts.
- `mise.toml` - Project tooling and task definitions.

## Repo Specific

### Badge On Bar

Badge On Bar reads other apps' Dock badge counts through the macOS Accessibility API and mirrors selected badges into separate menu bar items. It is a native macOS menu bar accessory: no Dock icon and no main window unless configuration is open. It is distributed as a signed and notarized repository release, not through the App Store.

### Apple App Architecture

- The app source is in `apps/apple/App`; the Xcode project is `apps/apple/App.xcodeproj`.
- `BadgeMonitor` owns Dock Accessibility polling, running and installed app discovery, and badge values.
- `AppSettings` is the single source of truth for persisted defaults and per-app overrides.
- `AppSettings` seeds defaults for newly discovered apps, removes stale overrides, and invokes its change callback after every persisted output mutation.
- `StatusBarManager` owns `NSStatusItem` lifecycle, click handling, icons, and badge rendering.
- `ConfigurationView` consumes `AppSettings` and `BadgeMonitor` through SwiftUI environment observation.
- `BadgeOnBarApp` and `AppDelegate` own activation policy, the configuration window, permissions startup, and lifecycle glue.
- Keep AppKit and Accessibility work on `@MainActor`. Use callbacks between AppKit managers and observable state.

### Monitoring and Display Behavior

- Start monitoring only after Accessibility trust is granted.
- When Accessibility trust changes, start or stop monitoring immediately so stale badge state is cleared after permission is revoked.
- Poll Dock badge values once per second; use AX observation only to invalidate the Dock element cache.
- Preserve `-1` as the non-empty, non-integer badge value.
- Resolve Dock entries from AX filename or URL, running app identity, bundle display name, then the installed app registry.
- Create and remove status items synchronously in `StatusBarManager.sync()` and always set `autosaveName` to `BadgeOnBar_<bundleID>`.
- Preserve badge, dot, count, and question display modes plus show, greyscale, and hide zero behavior.
- Resize icons by drawing into a new `NSImage`; do not use TIFF round-trips.
- Preserve the legacy dot-setting migration shims in `AppSettings`.

### Apple Workflow

- `mise test` runs the repository suite, including portable `AppSettings` tests.
- Use `mise simulate macos` to build and launch the app and `mise xcode` to open the project.
- Use `$publish` for versioning and the signed, notarized Codeberg and GitHub release workflow.
- Keep the app dependency-free and the configuration UI compact, native, and settings-first.
