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
