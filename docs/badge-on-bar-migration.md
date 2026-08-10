# Badge On Bar migration map

This migration audited all 43 files tracked by `/Users/graham/Code/badge-on-bar` at commit `2f272a5`. Build products, Git internals, user-specific Xcode state, credentials, `.DS_Store` files, and other ignored local files were excluded.

## Coverage totals

| Source group | Files | Disposition |
| --- | ---: | --- |
| `BadgeOnBar/BadgeOnBar/**` | 23 | Moved to `apps/apple/App/**`; 22 files remain byte-for-byte and `AppSettings.swift` only gained injectable `UserDefaults` for portable tests. |
| `BadgeOnBar/BadgeOnBar.xcodeproj/**` | 2 | Project file adapted to the new source root; generated workspace shell retired. |
| `assets/**` | 3 | Moved byte-for-byte. |
| `docs/**` | 1 | Moved byte-for-byte with the foundation filename convention. |
| `.agents/**` | 2 | Consolidated into Code Moto's publish workflow. |
| `scripts/**` | 5 | Icon generation adapted to the new Apple source path; four build and release files replaced by foundation tooling. |
| Root files and submodule | 7 | `.gitignore` and `AGENTS.md` merged, `LICENSE` retained, `README.md` adapted, `mise.toml` replaced by the foundation task graph, and Doll metadata/reference source retired. |
| **Total** | **43** | Every tracked source file has a disposition below. |

The migrated icon catalog, bundled question image, shared assets, and privacy policy are byte-identical to their source files. The application remains version `0.6.0` with bundle identifier `com.grahamotte.badgeonbar2`. Code Moto's app configuration now contains only the native macOS target and sets `skip_app_stores` to `true`.

## Direct moves

| Source | Destination | Disposition |
| --- | --- | --- |
| `BadgeOnBar/BadgeOnBar/*.swift` | `apps/apple/App/*.swift` | All seven app source files moved. `AppSettings.swift` gained a defaulted `UserDefaults` initializer dependency; the other six are unchanged. |
| `BadgeOnBar/BadgeOnBar/Assets.xcassets/**` | `apps/apple/App/Assets.xcassets/**` | All 13 catalog files moved byte-for-byte. |
| `BadgeOnBar/BadgeOnBar/Info.plist` | `apps/apple/App/Info.plist` | Accessibility usage and application category configuration moved byte-for-byte. |
| `BadgeOnBar/BadgeOnBar/BadgeOnBar.entitlements` | `apps/apple/App/BadgeOnBar.entitlements` | Non-sandboxed app entitlement configuration moved byte-for-byte. |
| `BadgeOnBar/BadgeOnBar/question.png` | `apps/apple/App/question.png` | Runtime question-display asset moved byte-for-byte. |
| `assets/logo.png` | `assets/logo.png` | Repository logo moved byte-for-byte. |
| `assets/question.png` | `assets/question.png` | Shared question asset moved byte-for-byte. |
| `assets/screenshot.png` | `assets/screenshot.png` | README screenshot moved byte-for-byte. |
| `docs/privacy_policy.md` | `docs/privacy-policy.md` | Privacy policy moved byte-for-byte and normalized to the foundation filename. |

## Merges and replacements

| Source | Destination | Disposition |
| --- | --- | --- |
| `BadgeOnBar/BadgeOnBar.xcodeproj/project.pbxproj` | `apps/apple/App.xcodeproj/project.pbxproj` | Moved into Code Moto's Apple project slot. The synchronized source root and plist/entitlement paths changed from `BadgeOnBar` to `App`, and `Info.plist` was excluded from resource copying because it is already the target's processed plist; target, product, version, deployment target, signing behavior, and bundle identifier remain intact. |
| `README.md` | `README.md` | Replaced the foundation placeholder and updated local, testing, and direct-release commands for Code Moto. |
| `.gitignore` | `.gitignore` | Xcode, SwiftPM, local credential, generated build, package, and user-state exclusions were merged into Code Moto's broader list. |
| `AGENTS.md` | `AGENTS.md` | Product architecture, Accessibility monitoring, display semantics, lifecycle boundaries, and direct-distribution guidance were adapted to `apps/apple/App` and merged with foundation rules. |
| `LICENSE` | `LICENSE` | The source and destination files were byte-identical, so the existing foundation copy was retained. |
| `mise.toml` | `mise.toml` | The Code Moto task graph remains authoritative. `mise simulate macos` replaces the old build/start flow, `$publish` replaces its release tasks, and `mise xcode` opens the migrated project. |
| `.agents/skills/publish/SKILL.md` | `.agents/skills/publish/SKILL.md` | Replaced by Code Moto's resumable Developer ID, notarization, Codeberg, and GitHub workflow and branded for Badge On Bar's repository-only distribution. |
| `.agents/skills/version-bump/SKILL.md` | `.agents/skills/publish/SKILL.md` | Semantic-version analysis is part of Code Moto's publish skill and `deploy:set-version` implementation. |
| `scripts/generate-assets.sh` | `scripts/generate-assets.sh` | Preserved with its icon catalog destination updated to `apps/apple/App`; exposed as `mise app:generate-assets`. |

## Retired source-only infrastructure

| Source | Replacement or exclusion reason |
| --- | --- |
| `BadgeOnBar/BadgeOnBar.xcodeproj/project.xcworkspace/contents.xcworkspacedata` | Xcode-generated single-project workspace shell; the migrated project generates it when needed. |
| `.gitmodules` | The Doll submodule is not a runtime or build dependency and is no longer needed after the native rewrite. |
| `Doll` | Historical reference source pinned as a submodule; it remains available from its upstream repository and the source repository history. |
| `scripts/ExportOptions-DeveloperID.plist` | Replaced by the Developer ID export options generated by `deploy/patches/apps/revision_patch.rb`. |
| `scripts/build.sh` | Replaced by `mise simulate macos` for local builds and the configured archive pipeline for releases. |
| `scripts/start.sh` | Replaced by `mise simulate macos`, which stops, builds, and launches the configured product. |
| `scripts/publish.sh` | Replaced by `mise deploy:publish` and `$publish`, including Developer ID signing, notarization, and uploads to both repository hosts. |

## Foundation files intentionally retained

The Rails backend, React frontend/toolchain, deploy system, shared gems, foundation tests, environment layout, maintenance skills, and Android placeholder remain in place. Public and local environment branding and repository defaults were updated for `badgeonbar.com`. The template Focus Timer sources/test, iOS and tvOS targets, template icons, placeholder screenshots, App Store export options, and `README.txt` were removed because Badge On Bar is a macOS-only repository-distributed application.

The source repository's ignored `.build/`, `dist/`, `.env`, `certs/`, `xcuserdata/`, `.DS_Store`, and Git metadata were not transferred because they are generated, secret, user-specific, or repository-local state.

## File-by-file verification audit

The source Git index was re-audited after migration rather than relying on the migration plan. Directly moved files were compared byte-for-byte, the old and new Release build settings were compared, and every tracked source entry received an individual resolution below. The only intentional application-code difference is the injectable `UserDefaults` dependency in `AppSettings.swift`; the project-file differences are the relocated paths and the explicit `Info.plist` resource exclusion described above.

| Source entry | Resolution in this repository |
| --- | --- |
| `.agents/skills/publish/SKILL.md` | Merged into the current Badge On Bar `$publish` skill and Code Moto's resumable direct-release pipeline. |
| `.agents/skills/version-bump/SKILL.md` | Merged into `$publish` plus `mise deploy:set-version`. |
| `.gitignore` | Merged; all meaningful source patterns are covered, including `.DS_Store`, build output, credentials, SwiftPM state, and Xcode user state. `/.netrc` is intentionally root-scoped. |
| `.gitmodules` | Retired with the unused Doll reference submodule. |
| `AGENTS.md` | Merged into the foundation rules and the repo-specific Badge On Bar architecture and behavior contract. |
| `BadgeOnBar/BadgeOnBar.xcodeproj/project.pbxproj` | Adapted as `apps/apple/App.xcodeproj/project.pbxproj`; product and Release behavior are equivalent. |
| `BadgeOnBar/BadgeOnBar.xcodeproj/project.xcworkspace/contents.xcworkspacedata` | Omitted as generated Xcode single-project workspace state. |
| `BadgeOnBar/BadgeOnBar/AppBadgeInfo.swift` | Byte-identical at `apps/apple/App/AppBadgeInfo.swift`. |
| `BadgeOnBar/BadgeOnBar/AppSettings.swift` | Moved to `apps/apple/App/AppSettings.swift`; behavior preserved, with injectable defaults added for tests. |
| `BadgeOnBar/BadgeOnBar/Assets.xcassets/AccentColor.colorset/Contents.json` | Byte-identical at the corresponding `apps/apple/App` path. |
| `BadgeOnBar/BadgeOnBar/Assets.xcassets/AppIcon.appiconset/Contents.json` | Byte-identical at the corresponding `apps/apple/App` path. |
| `BadgeOnBar/BadgeOnBar/Assets.xcassets/AppIcon.appiconset/icon_128x128.png` | Byte-identical at the corresponding `apps/apple/App` path. |
| `BadgeOnBar/BadgeOnBar/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png` | Byte-identical at the corresponding `apps/apple/App` path. |
| `BadgeOnBar/BadgeOnBar/Assets.xcassets/AppIcon.appiconset/icon_16x16.png` | Byte-identical at the corresponding `apps/apple/App` path. |
| `BadgeOnBar/BadgeOnBar/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png` | Byte-identical at the corresponding `apps/apple/App` path. |
| `BadgeOnBar/BadgeOnBar/Assets.xcassets/AppIcon.appiconset/icon_256x256.png` | Byte-identical at the corresponding `apps/apple/App` path. |
| `BadgeOnBar/BadgeOnBar/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png` | Byte-identical at the corresponding `apps/apple/App` path. |
| `BadgeOnBar/BadgeOnBar/Assets.xcassets/AppIcon.appiconset/icon_32x32.png` | Byte-identical at the corresponding `apps/apple/App` path. |
| `BadgeOnBar/BadgeOnBar/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png` | Byte-identical at the corresponding `apps/apple/App` path. |
| `BadgeOnBar/BadgeOnBar/Assets.xcassets/AppIcon.appiconset/icon_512x512.png` | Byte-identical at the corresponding `apps/apple/App` path. |
| `BadgeOnBar/BadgeOnBar/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png` | Byte-identical at the corresponding `apps/apple/App` path. |
| `BadgeOnBar/BadgeOnBar/Assets.xcassets/Contents.json` | Byte-identical at the corresponding `apps/apple/App` path. |
| `BadgeOnBar/BadgeOnBar/BadgeMonitor.swift` | Byte-identical at `apps/apple/App/BadgeMonitor.swift`. |
| `BadgeOnBar/BadgeOnBar/BadgeOnBar.entitlements` | Byte-identical at `apps/apple/App/BadgeOnBar.entitlements`. |
| `BadgeOnBar/BadgeOnBar/BadgeOnBarApp.swift` | Byte-identical at `apps/apple/App/BadgeOnBarApp.swift`. |
| `BadgeOnBar/BadgeOnBar/ConfigurationView.swift` | Byte-identical at `apps/apple/App/ConfigurationView.swift`. |
| `BadgeOnBar/BadgeOnBar/Info.plist` | Byte-identical at `apps/apple/App/Info.plist`. |
| `BadgeOnBar/BadgeOnBar/PermissionsManager.swift` | Byte-identical at `apps/apple/App/PermissionsManager.swift`. |
| `BadgeOnBar/BadgeOnBar/StatusBarManager.swift` | Byte-identical at `apps/apple/App/StatusBarManager.swift`. |
| `BadgeOnBar/BadgeOnBar/question.png` | Byte-identical at `apps/apple/App/question.png`. |
| `Doll` | Retired; its pinned reference source was not used by the target, build, or runtime. |
| `LICENSE` | Byte-identical root file retained. |
| `README.md` | Adapted to Code Moto paths, tasks, tests, and repository-only distribution. |
| `assets/logo.png` | Byte-identical root asset retained. |
| `assets/question.png` | Byte-identical root asset retained. |
| `assets/screenshot.png` | Byte-identical root asset retained. |
| `docs/privacy_policy.md` | Byte-identical as `docs/privacy-policy.md`; filename normalized. |
| `mise.toml` | Merged into Code Moto's task graph; the asset generator is exposed as `app:generate-assets`. |
| `scripts/ExportOptions-DeveloperID.plist` | Replaced by dynamically generated Developer ID export options in the revision patch. |
| `scripts/build.sh` | Replaced by `mise simulate macos` locally and Code Moto's archive patch for releases. |
| `scripts/generate-assets.sh` | Preserved with the new icon catalog path. |
| `scripts/publish.sh` | Replaced by `$publish` and `mise deploy:publish`, including signing, notarization, stapling, and dual-host upload. |
| `scripts/start.sh` | Replaced by `mise simulate macos`, which stops, builds, and launches the app. |

Release configuration was also checked independently of file mapping. Badge On Bar remains macOS-only, signed with Developer ID, hardened, notarized, and configured with `skip_app_stores: true`. Releases now target the `badgeonbar.com` repositories on Codeberg and GitHub rather than the legacy `badge-on-bar` repository names; that is an intentional destination migration, not a missing source behavior. The ignored source `.env` and certificate directory were not copied, but the new ignored production environment defines every credential category required by the Code Moto direct-release flow.
