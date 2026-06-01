---
name: "version-bump"
description: "Use when the user wants to bump Scamp Micro Deck's version. Review changes since the most recent commit whose subject is exactly `Version`, choose the smallest sensible semantic version bump, update every `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `ScampMicroDeck.xcodeproj/project.pbxproj`, run `mise build`, and if it passes commit the bump with subject `Version`."
---

# Version Bump

Use this skill when the user wants to bump Scamp Micro Deck's version.

Do the analysis yourself. Do not add or run a repo helper script for this skill.

## Workflow

1. Find the most recent commit whose subject is exactly `Version`.
2. Review the commits since that point. Inspect the code diff when commit subjects are not enough.
3. Choose the smallest sensible semantic version bump:
   - `major` for intentional breaking changes.
   - `minor` for new user-visible capability.
   - `patch` for fixes, polish, refactors, and internal work that do not expand capability.
4. If the selected bump is `major`, stop and ask the user to confirm before changing files. Do not ask for confirmation for `minor` or `patch` bumps.
5. Update every `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `ScampMicroDeck.xcodeproj/project.pbxproj`.
6. Run `mise build`.
7. If `mise build` passes, commit the version bump with the subject `Version`.
8. Report the old version, new version, and short reasoning.

## Guidance

- Prefer judgment over commit-message rules. Read the code when needed.
- Default to the smaller bump when the change is ambiguous.
- Keep the version bump commit subject as `Version` so the next bump has a clean boundary.
- Do not run `mise start` for this skill.
