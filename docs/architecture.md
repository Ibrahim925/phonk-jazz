# Architecture

> Read this before touching how the menubar, WebView, hotkey, and config fit together.

## The shape

```
  Global shortcuts (Carbon)       Menubar (NSStatusItem)
   ⌃⌥⌘J toggle · ⌃⌥⌘P play        click -> now-playing panel
              \                        /
               \                      /
                v                    v
             ┌────────────────────────────┐
             │      AppController          │   holds current Mode,
             │  (Sources/PhonkJazz)        │   maps intent -> playlist,
             │                             │   polls state for the panel
             └──────────────┬─────────────┘
                            │  evaluateJavaScript / navigate
                            v
             ┌────────────────────────────┐
             │   Hidden WKWebView          │   music.youtube.com
             │   (off-screen, persistent)  │   user's logged-in session
             └────────────────────────────┘
                            ^
                            │ reads
             ┌────────────────────────────┐
             │   AppConfig (Core)          │   two playlist URLs +
             │   JSON in Application Support│   two shortcut bindings
             └────────────────────────────┘
```

## Why these choices
- **Embed the web player, don't call an API.** YouTube Music has no official
  streaming API; unofficial metadata APIs (e.g. ytmusicapi) can't play audio. The
  only reliable way to *play* a playlist is to drive the real web player in a
  `WKWebView`. See `docs/ytmusic-integration.md`.
- **Menubar-only via accessory policy.** `NSApp.setActivationPolicy(.accessory)`
  gives a status-bar app with no Dock icon and no main window — the headless
  requirement. The bundled `.app` sets `LSUIElement` for the same effect
  (feature `app-bundle-packaging`).
- **Carbon hotkey, not a NSEvent global monitor.** `RegisterEventHotKey` fires a
  true system-wide hotkey and does **not** require the Accessibility permission a
  global `NSEvent` monitor would. Lower install friction.
- **One hotkey handler, routed by id.** Carbon delivers hotkey events to *every*
  handler installed on the application event target, so one handler per hotkey
  makes each handler fire for all of them. `HotKeyCenter` installs a single
  handler and dispatches on `EventHotKeyID`; rebinding is a wholesale re-apply.
- **The status item has no `NSMenu`.** Assigning `statusItem.menu` makes AppKit
  swallow the click to open the menu, which would make the panel unreachable. The
  button targets `AppController` directly and the old menu commands live inside
  the panel (its "…" button).

## Module boundary (enforced)
`PhonkJazzCore` is pure Swift — **no AppKit, no WebKit** — so its logic (mode
toggling, config model/serialization, URL validation) is unit-testable without a
display. The `PhonkJazz` executable is the only place that imports AppKit/WebKit.
Keep new testable logic in Core. Executable check:

    # Core must not import AppKit or WebKit
    grep -rn "import AppKit\|import WebKit" Sources/PhonkJazzCore/ && exit 1 || echo OK

## Control flow of a toggle
1. Shortcut (or the panel's mode button) fires -> `AppController` computes
   `mode = mode.toggled`.
2. Controller looks up the playlist URL for the new mode from `AppConfig`.
3. Controller drives the WebView to load + play that playlist (JS injection).
4. Controller updates the `NSStatusItem` to reflect the new mode.

Steps 1–2 are Core-testable; 3–4 are GUI and verified via `make dev`.

## Control flow of the now-playing panel
1. Clicking the status item shows an `NSPopover` hosting
   `NowPlayingPanelController` and starts a 0.5s poll — **only** while the panel
   is open, so an idle menubar app stays asleep.
2. Each tick, `AppController` asks `PlayerController` for a snapshot; the page's
   answer is decoded into a Core `NowPlaying` and pushed to the panel, and it is
   also what corrects the app's optimistic `isPlaying` guess.
3. The panel emits `Command`s (play/pause, next, previous, seek, toggle mode,
   show player, settings, quit); `AppController` is the only thing that touches
   the player, so the panel never learns how playback works.
4. Formatting and clamping (`m:ss`, progress in `0...1`, seek target from a
   slider fraction) live in Core and are unit-tested; the AppKit views are not.
