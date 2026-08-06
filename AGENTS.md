# AGENTS.md

> Entry point for AI agents working in this repo. Read this first, then load the
> topic doc relevant to your task. Keep this file lean — deep detail lives in docs/.

## Overview
Phonk/Jazz is a macOS **menubar-only** desktop app. It embeds the YouTube Music
web player and exposes a single global shortcut (`Ctrl+Opt+Cmd+J`) that toggles
playback between an **instrumental-jazz** playlist (reading mode) and a **phonk**
playlist (focus/work mode). Success = from any app, one keypress flips between
the two playlists with no visible window required.

## Stack
| Piece | Choice |
|---|---|
| Language | Swift 6.3 (language mode 5) |
| UI | AppKit — `NSStatusItem` menubar, accessory activation policy (no Dock icon) |
| YTM access | `WKWebView` (WebKit) embedding music.youtube.com; JS injection for control |
| Global hotkey | Carbon `RegisterEventHotKey` (no Accessibility permission needed) |
| Build | Swift Package Manager (`Package.swift`) |
| Lint/format | `swift format` (bundled in toolchain — no external dependency) |
| Tests | XCTest via `swift test` |

## Quick start
- Setup:  `make setup`
- Dev:    `make dev`     # launches the menubar app (no Dock icon)
- Test:   `make test`
- Verify: `make check`   # swift-format lint + build (typecheck) + tests — the gate

## Project structure
- `Sources/PhonkJazzCore/` — pure, headless-testable domain logic (e.g. `Mode`). No AppKit/WebKit.
- `Sources/PhonkJazz/` — the AppKit menubar executable; owns WebKit, hotkey, UI.
- `Tests/PhonkJazzCoreTests/` — XCTest suite for the Core module.
- `docs/` — topic docs, loaded on demand (see below).
- `feature_list.json` — the ordered feature tracker (states + verifications).

## Session workflow
**Clock in (session start):**
1. Read `PROGRESS.md` (current verified state, blockers, next steps).
2. Read `DECISIONS.md` (why things are the way they are).
3. Run `make check` to confirm the repo starts consistent.
4. Continue from `PROGRESS.md` "Next Steps" / the one `in_progress` feature.

**Clock out (before ending any session that changed code):**
1. Update `PROGRESS.md` (truthful record: goal, outcome, verification actually run, commits, follow-ups).
2. Update `feature_list.json` states — only to `passing` when verification ran.
3. Run `make check`; leave a clean state (no debug code, no stray artifacts).
4. Commit completed work atomically.

## Definition of Done
A change is done only when verification has actually run — "code is written" is
not done. Do not advance a level until the prior one passes:
1. Lint + typecheck pass (`make lint`)
2. Tests pass (`make test`)
3. Manual UI/flow check when the change touches the menubar, hotkey, or WebView
   (GUI paths can't be unit-tested headlessly — exercise them via `make dev`).
Report honestly: state what ran, what passed, what was skipped.

## Work rules
- WIP = 1: exactly one feature `in_progress` at a time. Finish and verify it first.
- A feature becomes `passing` only when its verification actually passed. Do not
  self-declare done; run the verification and let it decide.
- Keep testable logic in `PhonkJazzCore` (pure) so it can be covered without a display.

## Boundaries
- **Always:** run `make check` before committing; keep `PhonkJazzCore` free of AppKit/WebKit.
- **Ask first:** adding any SwiftPM dependency; changing the global shortcut default;
  storing anything beyond playlist config; schema/config-format changes.
- **Never:** commit secrets or the user's Google/YTM session data; put login
  credentials in the repo; delete a failing test to go green.

## Topic docs (load on demand — don't guess)
- `docs/architecture.md` — read this before touching how the menubar, WebView, hotkey, and config fit together.
- `docs/ytmusic-integration.md` — read this when working on the WebView, login persistence, or JS playback control.
- `docs/code-style.md` — read this before writing Swift here (conventions + target boundaries).
