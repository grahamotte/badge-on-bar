# Scamp Micro Deck Agent Guide

## Product Goal

## UX

## Technical Defaults

- Use Swift for implementation.
- Use SwiftUI for UI and AppKit only when required.
- Target the latest stable macOS major version (currently macOS 26.2) unless explicitly changed.
- Strongly prefer native window and control styling.

## Workflow

- Keep changes in thin, testable vertical slices.
- Keep playback engine, queue state, ingestion, and visualization as separate concerns.
- After code changes, run `mise build` and report result.

## Collaboration

- Call out incorrect assumptions about macOS, Swift, SwiftUI.
- Keep recommendations practical and biased toward momentum.
- Choose options that feel native, simple, and easy to evolve.
