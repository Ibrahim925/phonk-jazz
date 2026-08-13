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
- **Branch/commit:** `main` = `e97023f` (now-playing panel) on `3f41f36`
  (configurable shortcuts), rebased onto upstream `66fcbb3` (the webview
  memory/quality work). `make check` re-run green after the rebase.
- **Verification status:** `make check` green — swift-format lint 0 issues,
  `swift build` clean, `swift test` 23/23 passing (`ModeTests`, `ConfigTests`,
  `YTMURLTests`, `ShortcutTests`, `NowPlayingTests`). `make app` builds a
  menubar-only `PhonkJazz.app` (LSUIElement=true) that launches and persists.
- **Start:** `make dev` (or `make app` then open `PhonkJazz.app`). The status item
  shows mode + play state; **clicking it opens the now-playing panel** (artwork,
  title/artist/album, seek bar, prev/play/next, mode button, and a "…" menu with
  Sign in / Settings / Quit — there is no separate NSMenu any more). Global
  shortcuts: ⌃⌥⌘J toggles jazz/phonk, ⌃⌥⌘P toggles play/pause; both rebindable in
  Settings.
- **Verified against the live site this session** (throwaway headless WKWebView
  probe, non-persistent store, running the *shipped* scripts): metadata reads
  `{"title":"Vois Sur Ton Chemin","artist":"deprezz","duration":187}`, and
  `seek(30)` returns `api` with `currentTime` reading back 30. Panel layout smoke
  (panel source compiled against Core) passes with no constraint conflicts.
- **Accepted by the user 2026-08-12 (GUI, on their machine):** signed into Google
  in-app and heard real audio; session survived quit + relaunch; ⌃⌥⌘P toggled
  playback from another app; ⌃⌥⌘J flipped the playlist and the status item; a
  rebound shortcut fired on its new combination; the panel showed artwork and
  track text, the seek bar advanced and scrubbed, prev/next changed track. Nine of
  ten features are now `passing`.
- **Next priority:** finish the one remaining half-verification —
  `settings-window` still needs "change a *playlist* URL, save, toggle, confirm
  the new playlist plays" and "an invalid URL raises the alert". Then the app is
  feature-complete against the current list.
- **Blockers:** (1) Bundle is unsigned — Gatekeeper may need right-click > Open
  (or an ad-hoc/Developer ID signature). (2) Nothing else: every GUI path in the
  list has now been exercised on a real display except the two settings checks
  above.
- **Known behaviour, not a bug:** logged out, YTM plays **ads** whose metadata
  also lands in the media session, so the panel will happily display an ad as a
  "track". Signed in, this doesn't arise.

## Session Records

### 2026-08-12 (acceptance) — GUI verification on the user's machine
- Outcome: done. The user confirmed all six outstanding GUI checks; nine of ten
  features moved to `passing` in `feature_list.json`, each with what was actually
  observed recorded in its `evidence`.
- Did: flipped `embed-ytm-webview`, `playback-control-js`, `mode-toggle`,
  `global-hotkey`, `configurable-shortcuts` and `now-playing-panel` to `passing`;
  refreshed `global-hotkey`'s evidence, which still referenced the deleted
  `GlobalHotKey.swift` instead of `HotKeyCenter.swift`.
- Deliberately NOT marked passing: `settings-window`. The user exercised the
  window, the save path and shortcut rebinding, but not its own stated
  verification (change a playlist URL -> next toggle uses it; invalid URL ->
  alert). Left `blocked` with the remaining half named, rather than inflating it
  on adjacent evidence.
- Verification run: user acceptance as above; `make check` green (23/23) and CI
  run #31633914896 green on the pushed HEAD.
- Risks / follow-ups: unsigned bundle; player-bar selectors for prev/next remain
  the most redesign-fragile surface; artwork has no disk cache.

### 2026-08-11 (feature) — Configurable shortcuts + now-playing panel
- Outcome: both features code-complete, automated + live-page verification green;
  GUI acceptance (audio, physical keypress, panel visuals) pending on the user's
  machine. Decisions were taken with the user up front (default binding, panel vs
  menu, both bindings rebindable, full transport incl. scrubbing).
- Did: **Shortcuts** — new Core `Shortcut`/`ModifierKeys` (pure, no Carbon in
  Core) with a key-name table, validity rule (needs ⌃/⌥/⌘), and `AppConfig`
  carrying both bindings with additive decoding; replaced `GlobalHotKey` with
  `HotKeyCenter` (one Carbon handler routed by `EventHotKeyID` — the old
  one-handler-per-hotkey shape would have fired every callback for every hotkey),
  added `ShortcutRecorderView` (click-to-record, intercepts `performKeyEquivalent`
  so ⌘-combos are capturable) and two recorder rows in Settings with
  collision/validity alerts; `AppController.applyHotKeys()` re-registers on save.
  **Panel** — new Core `NowPlaying` (tolerant decoding, `m:ss`, clamped progress,
  seek target), `NowPlayingPanelController` in an `NSPopover` (artwork, text,
  draggable seek bar, prev/play/next, mode button, "…" menu), `PlayerController`
  gained next/previous/seek/fetchNowPlaying, `AppController` owns the popover and
  polls 0.5s **only while it is open**; `statusItem.menu` removed.
- Found while verifying (the session's real discovery): the page's single
  `<video>` reports `duration: NaN`, `readyState: 0`, `currentTime: 0`
  indefinitely while `paused` is `false`, so the previous media-element-only
  scripts would have produced a frozen `0:00 / --:--` seek bar and an inverted
  play state, and `video.currentTime = x` is a silent no-op. `YTMScript` was
  rewritten around shared helpers that read `#movie_player` first (state, times,
  `seekTo`), with the media element and player bar as fallbacks — recorded in
  DECISIONS.md and docs/ytmusic-integration.md.
- Verification run: `make check` green (lint 0, build clean, 23/23 tests — 13 new
  across `ShortcutTests` + `NowPlayingTests`); live headless probe of the shipped
  scripts (metadata + duration + `seekTo` round-trip); panel layout smoke (view
  loads, 9 subviews, slider 0.1604 == 30/187, idle disables the bar, no constraint
  conflicts); release `.app` launch smoke (accessory process alive, then killed).
  NOT run: Google login, real audio, physical global keypress, visual panel check.
- Risks / follow-ups: `next`/`previous` rely on player-bar selectors (most
  redesign-fragile part, `#movie_player.nextVideo()` is the fallback); artwork is
  fetched over the network per track change (cached by URL, no disk cache); ads
  in a logged-out session surface as "tracks"; bundle still unsigned.
- Rebase note: `git pull --rebase` brought in upstream `66fcbb3` (cap video
  quality / prefer audio to cut WebContent memory), which conflicted in
  `YTMScript.swift` — that commit appended `preferAudioLowData` to the same file
  this session rewrote around shared state helpers. Resolved by keeping the
  rewrite and re-adding `preferAudioLowData` verbatim (its `#movie_player` quality
  API and `.song-button` selectors were verified separately on 2026-08-06 and were
  left untouched). `PlayerController` auto-merged: the 15s re-apply timer and this
  session's next/previous/seek/fetchNowPlaying coexist. `make check` green after
  resolving (23/23).

### 2026-08-06 (open-source) — Publish public MIT repo
- Outcome: done. Repo live and public at https://github.com/Ibrahim925/phonk-jazz.
- Did: Added MIT `LICENSE` (© 2026 Ibrahim Khawar), `README.md`,
  `CONTRIBUTING.md`, and `.github/` (CI workflow + PR/issue templates), mirroring
  the omp-plug open-sourcing layout. Also fixed playback (was `/playlist?list=`,
  now `/watch?list=` via `YTMURL.watchURL`) and the Google sign-in webview block
  (desktop Safari UA). Created the repo with `gh repo create --public` and pushed.
- Verification run: `make check` green locally; GitHub confirms visibility=PUBLIC,
  license=MIT, default branch main. CI workflow active + Actions enabled; a
  `workflow_dispatch` run was queued (macOS hosted-runner queue delay) — CI runs
  the same `make check` this repo passes locally.
- Risks / follow-ups: confirm the CI run goes green once the macOS runner starts;
  the `.app` is unsigned (Gatekeeper). No secrets/session data are in the repo.

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
