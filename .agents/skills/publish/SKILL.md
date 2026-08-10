---
name: publish
description: Version and publish Badge On Bar as signed and notarized Codeberg and GitHub repository releases. Use only when the user explicitly invokes `$publish` or asks to use the publish skill by name.
---

# Publish

## Prepare

1. Run `git status --porcelain` before doing anything else. Stop and summarize the files if the worktree is dirty.
2. Verify the current branch is `master`; `mise deploy:push` force-pushes local `master` to the configured Codeberg and GitHub remotes. Stop on another branch.
3. Record `HEAD`, the configured remotes, and commits not yet present on them when available.
4. Read the configured targets from `apps/config.json`; do not assume a fixed platform list.

## Version

1. Find the most recent commit whose subject is exactly `Version`.
   - If none exists, find the commit that introduced the current `version` in `apps/config.json`.
2. Review every subsequent commit and inspect diffs when subjects are insufficient.
3. Choose the smallest sensible semantic version bump:
   - `major` for intentional breaking changes.
   - `minor` for new user-visible capability.
   - `patch` for fixes, polish, refactors, and internal work.
4. Stop and ask the user to confirm a `major` bump. Do not ask for `minor` or `patch` confirmation.
5. If there are no release-worthy changes, choose a patch bump and continue. The user's publish request authorizes creating a new version even without notable changes.
6. Set `whatsNew` in `apps/config.json` to a concise, user-facing summary grounded in the reviewed changes. Use exactly `Bug fixes.` when nothing user-facing is notable.
7. Run `mise deploy:set-version <version>`.
8. Run `mise test`. Stop on failure.
9. Commit only `apps/config.json` and the Xcode project files changed by the version task with the subject `Version`.

## Publish

1. Run `mise deploy:push`. Stop on failure.
2. Run `mise deploy:publish`; do not manually reproduce or skip its stages.
3. Follow its output through validation, the macOS archive, Developer ID export, notarization, and both repository uploads.
4. Stop on failure and report the target and stage. Do not edit the deploy cache or bypass validation.

The task publishes the signed and notarized macOS revision to both configured repository hosts. Badge On Bar intentionally skips App Store Connect because its Accessibility behavior is not eligible for App Store distribution.

## Report

Report the old and new versions, bump reasoning, `whatsNew`, the `Version` commit, pushed remotes, and both repository-release statuses. Use task output and its latest log as the source of truth.
