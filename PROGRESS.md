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
- **Branch/commit:** app implemented on top of the harness checkpoint.
- **Verification status:** `make check` green — swift-format lint 0 issues,
  `swift build` clean, `swift test` 6/6 passing (`ModeTests` + `ConfigTests`).
  `make app` builds a menubar-only `PhonkJazz.app` (LSUIElement=true) that launches.
- **Start:** `make dev` (or `make app` then open `PhonkJazz.app`) launches the
  menubar app: status item shows mode + play state; menu = Toggle / Play-Pause /
  Sign in-Show Player / Settings / Quit; global hotkey Ctrl+Opt+Cmd+J toggles.
- **Next priority:** manual acceptance on the user's machine — open "Sign in /
  Show Player…" and log into Google, confirm audio plays, confirm the hotkey
  toggles. See the `blocked` features in `feature_list.json`.
- **Blockers:** (1) Audio/login/keypress are GUI-only, verifiable only via
  `make dev` on a real display with the user's Google account. (2) Bundle is
  unsigned — Gatekeeper may need right-click > Open (or a signature).

## Session Records

### 2026-08-06 (implement) — Build the full app
- Outcome: code complete; automated + launch verification green; GUI/login/audio
  acceptance pending on the user's machine.
- Did: Implemented all features on the harness. Core: `AppConfig` + `ConfigStore`
  (JSON in Application Support, user's playlists as defaults) with tests. App:
  `PlayerController` (persistent WKWebView + JS playback, autoplay retry),
  `YTMScript` (centralized YTM selectors), `GlobalHotKey` (Carbon,
  Ctrl+Opt+Cmd+J), `SettingsWindowController` (edit+validate URLs),
  `AppController` (owns Mode/config/player/hotkey/menu; wires toggle). `make app`
  now assembles a real LSUIElement `.app`.
- Verification run: `make check` green (lint 0, build clean, tests 6/6);
  Core-import boundary grep OK; `make app` → bundle with LSUIElement=true;
  release binary launches as persistent accessory process. NOT run: Google login,
  actual audio playback, physical hotkey press (all require the user's machine).
- Risks / follow-ups: no in-app Sign-in UI yet (WebView is off-screen); YTM
  autoplay may need a user gesture / selector tuning (centralized in YTMScript);
  bundle unsigned; hotkey collision unverified.

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
