<div align="center">

<h1>phonk-jazz</h1>

<p><b>One shortcut. Jazz for reading, phonk for working.</b></p>

<p>A macOS menubar app that plays YouTube Music and flips between an instrumental-jazz playlist and a phonk playlist on a single global hotkey — so you can drop from reading into real work without touching the mouse.</p>

<p>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-black.svg" alt="License: MIT" /></a>
  <img src="https://img.shields.io/badge/Swift-6-black" alt="Swift 6" />
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-black" alt="Platform: macOS 13+" />
</p>

<p>
  <a href="#what-you-get">Features</a> ·
  <a href="#how-it-works">How it works</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="#contributing">Contributing</a>
</p>

</div>

---

It lives in the menubar with no Dock icon and no window in your way. Press **⌃⌥⌘J** from any app and it toggles between two playlists: calm instrumental jazz for reading, phonk for when you start doing the work. Nothing to alt-tab to, no player to babysit.

## Why this exists

Switching the vibe shouldn't cost a context switch. You're reading with jazz on, you decide it's time to actually build something, and you want the beat to match — without leaving the doc, finding the music tab, and hunting for the right playlist. One keypress does it and you never look away.

## What you get

- **One global shortcut** (`⌃⌥⌘J`) toggles jazz ⇄ phonk from anywhere, no window focus needed.
- **Real YouTube Music playback** — it drives the actual web player (your account, your library), not a metadata API.
- **Menubar-only** — accessory app, no Dock icon; the status item shows the current mode (JZ/PH) and play state.
- **Your playlists** — ships with defaults; edit both URLs in a small Settings window, persisted to a local config file.
- **Sign in once** — a "Sign in / Show Player…" item surfaces the web player so you log into Google a single time; the session persists across launches.

## How it works

```
  ⌃⌥⌘J (Carbon hotkey)        Menubar (NSStatusItem)
            \                    /
             v                  v
        ┌────────────────────────────┐
        │       AppController         │  holds Mode, maps intent -> playlist
        └──────────────┬─────────────┘
                       │  navigate + evaluateJavaScript
                       v
        ┌────────────────────────────┐
        │   WKWebView (music.youtube) │  your logged-in session; audio plays
        └────────────────────────────┘
```

Native Swift/AppKit. The two "modes" are pure, testable logic in `PhonkJazzCore`; the executable owns the AppKit menubar, the embedded `WKWebView`, and the Carbon global hotkey. To actually start a playlist it navigates to the YTM **watch** URL (`/watch?list=…`), which cues the first track and plays — a plain `/playlist?list=…` page only sits there paused. Deeper detail is in [`docs/architecture.md`](docs/architecture.md) and [`docs/ytmusic-integration.md`](docs/ytmusic-integration.md).

## Requirements

- macOS 13 or newer (Apple Silicon or Intel).
- Xcode 16 / Swift 6 toolchain (`swift format` ships with it — no extra lint dependency).
- A YouTube Music account you sign into once, in-app.

## Quick start

```sh
git clone https://github.com/Ibrahim925/phonk-jazz.git
cd phonk-jazz
make setup          # resolve SwiftPM deps
make app            # build PhonkJazz.app (menubar-only, LSUIElement)
open PhonkJazz.app
```

The binary is unsigned, so on first launch Gatekeeper may block it — **right-click the app → Open** once to allow it. Prefer running from source during development? `make dev` launches it via `swift run`.

Once it's in the menubar: click the status item → **Sign in / Show Player…**, log into Google, close that window (audio keeps playing). Now press **⌃⌥⌘J** from anywhere to toggle.

## Configuration

Your two playlists are editable in **Settings…** (validated against `music.youtube.com/...?list=`) and persist to:

```
~/Library/Application Support/PhonkJazz/config.json
```

```json
{ "jazzURL": "https://music.youtube.com/playlist?list=...",
  "phonkURL": "https://music.youtube.com/playlist?list=..." }
```

## A note on the embedded player

Google refuses to sign you in from a bare embedded webview ("this browser may not be secure"). phonk-jazz presents a desktop **Safari** User-Agent so Google treats the `WKWebView` as Safari — which it genuinely is, same WebKit engine — and login works. YTM's DOM selectors aren't a stable contract; they're centralized in one file (`Sources/PhonkJazz/YTMScript.swift`) so a redesign is a one-line fix.

## Development

```sh
make dev       # run the menubar app via swift run
make test      # XCTest suite (headless — the Core logic)
make check     # the gate: swift-format lint + build + tests
```

`make check` is what CI runs. Testable logic stays in `PhonkJazzCore` (no AppKit/WebKit), so the toggle, config, and URL logic are covered without a display; the GUI/audio paths are verified by running it. Read [`docs/code-style.md`](docs/code-style.md) before writing code, and [`AGENTS.md`](AGENTS.md) for the layout.

## Contributing

Forks and pull requests welcome. Start with [`CONTRIBUTING.md`](CONTRIBUTING.md) for the dev loop and the few conventions that keep this honest. The `docs/` folder is the map.

## License

MIT — see [`LICENSE`](LICENSE).
