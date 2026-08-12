# Design Decisions

## 2026-08-06: Native Swift/AppKit menubar app (not Electron/Tauri)
- Reason: User chose a truly native macOS menubar-only app. `NSStatusItem` +
  `.accessory` activation policy gives no-Dock, no-window headless behavior;
  smallest footprint; no runtime bundling of a browser engine.
- Rejected alternative: Electron (heaviest binary; easiest web-player embed) and
  Tauri (lighter, but embedding + JS-controlling the YTM player is less trodden).
- Constraint: all UI is AppKit; global hotkey and WebView are macOS-only. No
  cross-platform path.

## 2026-08-06: Play YTM by embedding the web player in WKWebView
- Reason: YouTube Music has no official streaming API. Unofficial metadata APIs
  cannot play audio. Driving the real web player in a persistent `WKWebView` is
  the only reliable way to actually play a playlist; user logs into Google once
  in-app.
- Rejected alternative: ytmusicapi / metadata-only APIs — read playlists but
  can't stream, so they don't satisfy "play a playlist."
- Constraint: control is via `evaluateJavaScript` against music.youtube.com,
  whose DOM/selectors are not a stable contract — centralize selectors so a YTM
  redesign is a one-file fix. Must persist login via `WKWebsiteDataStore.default()`.

## 2026-08-06: Global hotkey via Carbon RegisterEventHotKey
- Reason: `RegisterEventHotKey` registers a true system-wide hotkey without the
  Accessibility permission a global `NSEvent` monitor requires — lower install
  friction for a background utility.
- Rejected alternative: `NSEvent.addGlobalMonitorForEvents` (needs Accessibility
  grant); third-party HotKey SPM package (adds a dependency for a thin Carbon wrap).
- Constraint: default binding is `Ctrl+Opt+Cmd+J`; chosen to avoid common
  collisions. Rebinding is a later feature.

## 2026-08-06: SwiftPM with a pure Core target split from the AppKit executable
- Reason: A `PhonkJazzCore` library with no AppKit/WebKit keeps domain logic
  (mode toggle, config model, URL validation) unit-testable without a display,
  so `make check` is meaningful in CI/headless. SwiftPM avoids an Xcode-project
  dependency for agent CLI workflows.
- Rejected alternative: single Xcode app target (GUI-only, hard to test headless);
  everything in one executable target (nothing unit-testable without a display).
- Constraint: Core must never import AppKit/WebKit (enforced by a grep check in
  docs/code-style.md). Menubar `.app` distribution bundle assembled by `make app`
  (feature app-bundle-packaging), separate from `swift run` dev.

## 2026-08-06: swift-format for lint (bundled) instead of SwiftLint/SwiftFormat
- Reason: `swift format` ships in the Swift 6 toolchain — zero external
  dependency, works out of the box, satisfies the "ask first before adding deps"
  boundary.
- Rejected alternative: SwiftLint / nicklockwood SwiftFormat (both add an install
  step / dependency).
- Constraint: style rules live in `.swift-format`; `make lint` also runs
  `swift build` as the typecheck step.

## 2026-08-06: Off-screen WebView; in-app Sign-in UI deferred
- Reason: Audio plays whether or not the WebView is visible, so the player runs
  off-screen for a truly headless menubar feel. The default (persistent) data
  store keeps the Google session across launches.
- Rejected alternative: always showing the YTM window (defeats menubar-only) /
  scripting Google login (fragile, and handling someone's credentials is a
  non-goal).
- Constraint: first run has no way to surface Google sign-in — a "Sign in…" menu
  item (or one-time visible WebView) is a required follow-up before login works.
  Never log or persist session cookies anywhere but the WKWebsiteDataStore.

## 2026-08-06: Spoof desktop Safari UA to get Google sign-in in the WebView
- Reason: Google blocks OAuth sign-in from embedded webviews ("browser may not be
  secure — use Chrome/Firefox/Safari"). Setting `WKWebView.customUserAgent` to a
  real desktop Safari string makes Google treat it as Safari (which it is — same
  WebKit engine), so login proceeds. Verified: `navigator.userAgent` reports the
  spoofed string exactly.
- Rejected alternative: faking a Chrome/Firefox UA (rendering quirks serving
  non-WebKit code paths to a WebKit engine); external OAuth/system-browser login
  (no cookie transfer into the WebView; YTM isn't an OAuth client we own).
- Constraint: the `Version/` number in the UA drifts from current Safari over
  time; bump it in `PlayerController.safariUserAgent` if Google starts rejecting.

## 2026-08-11: Play/pause is its own configurable shortcut, default ⌃⌥⌘P
- Reason: User asked for a play/pause shortcut. `⌃⌥⌘P` reuses the modifier trio
  of the existing `⌃⌥⌘J` toggle, so the two read as one family, and collides with
  little. Both bindings are rebindable (user chose "both, in one pass") — the
  recorder and the id-routed handler make the second binding nearly free.
- Rejected alternative: the F8 / play-pause **media key** — Carbon can't register
  it; it needs a system-defined `NSEvent` tap plus the Accessibility permission
  this app deliberately avoids, and macOS/other players fight over it.
  `⌃⌥⌘Space` was also offered but Space collides more often.
- Constraint: this settles the "ask first: changing the global shortcut default"
  boundary. A binding with no ⌃/⌥/⌘ is refused (`Shortcut.isValid`) — a bare or
  Shift-only global hotkey would swallow ordinary typing in every app. If macOS
  refuses a registration, the app says so instead of leaving a dead key.

## 2026-08-11: Shortcuts live in AppConfig, decoded additively
- Reason: Bindings belong with the other user settings, so one file and one save
  path cover everything. Settles the "ask first: storing anything beyond playlist
  config" and "config-format changes" boundaries.
- Rejected alternative: `UserDefaults` for shortcuts (a second source of truth,
  and invisible to `ConfigStore`'s corrupt/missing handling).
- Constraint: `AppConfig.init(from:)` must keep using `decodeIfPresent` for every
  field added from now on. `ConfigStore.load()` falls back to `.defaults` when
  decoding **throws**, so a required new key would silently wipe the user's
  playlists on upgrade. `ShortcutTests` pins that migration.

## 2026-08-11: The menubar click opens a now-playing panel; the menu is folded in
- Reason: User asked to see the current song on click, with transport controls.
  An `NSPopover` can show artwork, title/artist/album, a draggable seek bar and
  prev/play/next; an `NSMenu` can't do that legibly. User chose panel-only, so the
  old commands (Toggle, Sign in, Settings, Quit) moved into the panel's "…" menu.
- Rejected alternative: left-click panel + right-click menu (two surfaces to
  learn); a custom view pinned inside the `NSMenu` (scrubbing inside a menu is
  cramped and fights menu event tracking).
- Constraint: `statusItem.menu` must stay unassigned — assigning it makes AppKit
  open the menu on click and the panel becomes unreachable. Polling runs at 0.5s
  **only while the popover is open** so an unwatched menubar app stays asleep.

## 2026-08-11: Player state comes from `#movie_player`, not the `<video>` element
- Reason: Measured on the live site — the single `<video>` is fed a `blob:` MSE
  stream and reports `duration: NaN`, `readyState: 0`, `currentTime: 0` forever
  while `paused` is `false`. Trusting it gives a seek bar frozen at `0:00` and an
  inverted play state, and assigning `currentTime` is a silent no-op. At the same
  moment `#movie_player.getDuration()` returned the true 110s and `seekTo(30, true)`
  worked (`currentTime` read back as 30).
- Rejected alternative: media-element-only (what the code did before — the reason
  the panel showed a dead seek bar); scraping `.time-info` text (loses precision,
  breaks with a redesign) — kept only as the last fallback tier.
- Constraint: `YTMScript` now reads through shared helpers with a fixed
  precedence (see docs/ytmusic-integration.md) and every snippet — play, pause,
  toggle, seek, next, previous, nowPlaying — goes through them, so the panel's
  reading and the shortcut's action can never disagree. Metadata comes from
  `navigator.mediaSession`, with the player bar as fallback.
