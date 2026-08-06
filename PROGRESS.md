# Progress Log

Session state for AI agents. Read at session start; update before ending any
session that changed code. Keep "Current Verified State" truthful — only record
what a verification command actually confirmed.

## Startup Readiness Checklist
- Setup: `make setup`  |  Dev: `make dev`  |  Test: `make test`  |  Verify: `make check`
- Environment: SwiftPM package resolves; `swift format` (bundled in toolchain,
  no external dep) + `swift build` + XCTest all wired. One example test passing.
- Toolchain: Swift 6.3.3 / Xcode 26.6 on arm64 macOS. Language mode 5.
- Structure: see AGENTS.md ("Project structure"). Testable logic in
  `Sources/PhonkJazzCore`; AppKit/WebKit app in `Sources/PhonkJazz`.

## Current Verified State
- **Branch/commit:** initial harness checkpoint — scaffold only, no features implemented.
- **Verification status:** `make check` green — swift-format lint 0 issues,
  `swift build` clean, `swift test` 2/2 passing (`ModeTests`).
- **Start:** `make dev` launches a menubar-only (accessory) status item showing
  the current mode + Quit. This is a scaffold; it does not yet play music.
- **Next priority:** first `not_started` feature in `feature_list.json` —
  `menubar-status-item` (flesh out the menubar into the real control surface),
  then `embed-ytm-webview`. Implement in a fresh session, WIP=1, TDD where logic
  is Core-testable.
- **Blockers:** none. Note: YTM login and audio playback are GUI-only paths that
  must be verified manually via `make dev` (they can't be unit-tested headlessly).

## Session Records

### 2026-08-06 (harness-init) — Initialize agent harness
- Outcome: done.
- Did: Greenfield init for a macOS menubar-only YouTube Music toggle app.
  Chose native Swift/AppKit + WKWebView (user-confirmed). Created SwiftPM package
  (`PhonkJazzCore` pure logic + `PhonkJazz` executable + XCTest target), the
  `Mode` domain type with the toggle invariant + example test, a minimal
  runnable menubar scaffold, `Makefile` (setup/dev/test/lint/format/check/app),
  `.swift-format`, `AGENTS.md` (+ `CLAUDE.md` symlink), `docs/` (architecture,
  ytmusic-integration, code-style), `PROGRESS.md`, `DECISIONS.md`,
  `feature_list.json`, `.gitignore`.
- Verification run: `swift build` clean; `swift test` 2/2 passing;
  `swift format lint --strict` 0 issues (i.e. `make check` green). App launch not
  smoke-run this session (GUI); scaffold builds and links AppKit.
- Risks / follow-ups: YTM DOM selectors are unstable (see docs). Autoplay may
  need a user gesture. Global hotkey uses Carbon (no Accessibility prompt) —
  verify no collision. Implementation is a SEPARATE phase from this checkpoint.
