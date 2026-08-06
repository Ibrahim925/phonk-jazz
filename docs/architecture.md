# Architecture

> Read this before touching how the menubar, WebView, hotkey, and config fit together.

## The shape

```
  Global hotkey (Carbon)          Menubar (NSStatusItem)
        Ctrl+Opt+Cmd+J                 icon + menu
              \                        /
               \                      /
                v                    v
             ┌────────────────────────────┐
             │      AppController          │   holds current Mode,
             │  (Sources/PhonkJazz)        │   maps intent -> playlist
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
             │   AppConfig (Core)          │   two playlist URLs + shortcut,
             │   JSON in Application Support│   defaults baked in
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

## Module boundary (enforced)
`PhonkJazzCore` is pure Swift — **no AppKit, no WebKit** — so its logic (mode
toggling, config model/serialization, URL validation) is unit-testable without a
display. The `PhonkJazz` executable is the only place that imports AppKit/WebKit.
Keep new testable logic in Core. Executable check:

    # Core must not import AppKit or WebKit
    grep -rn "import AppKit\|import WebKit" Sources/PhonkJazzCore/ && exit 1 || echo OK

## Control flow of a toggle
1. Hotkey (or menu item) fires -> `AppController` computes `mode = mode.toggled`.
2. Controller looks up the playlist URL for the new mode from `AppConfig`.
3. Controller drives the WebView to load + play that playlist (JS injection).
4. Controller updates the `NSStatusItem` to reflect the new mode.

Steps 1–2 are Core-testable; 3–4 are GUI and verified via `make dev`.
