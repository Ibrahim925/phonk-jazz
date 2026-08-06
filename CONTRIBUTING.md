# Contributing to phonk-jazz

Thanks for looking under the hood. It's a small, single-purpose macOS menubar
app with a clean split between pure logic and the AppKit/WebKit shell, so it's
easy to work on once you know where things live.

## Get set up

```sh
git clone https://github.com/Ibrahim925/phonk-jazz.git
cd phonk-jazz
make setup     # resolve SwiftPM deps (Swift 6 / Xcode 16)
make check     # confirm a clean checkout is green before you touch anything
```

The dev loop:

```sh
make dev       # run the menubar app via swift run
make test      # XCTest suite (headless Core logic)
make check     # the gate: swift-format lint + build + tests
```

`swift format` ships with the Swift 6 toolchain — there's no extra lint tool to
install. Run `make format` to auto-fix style before committing.

## The map

Read [`AGENTS.md`](AGENTS.md) first — it's the orientation doc and points at the
topic docs in `docs/`. Load the one that matches your change:

- [`docs/architecture.md`](docs/architecture.md) — how the menubar, WebView, hotkey, and config fit together.
- [`docs/ytmusic-integration.md`](docs/ytmusic-integration.md) — the WebView, login, playback (read before touching player JS).
- [`docs/code-style.md`](docs/code-style.md) — conventions + the Core/executable boundary. Read before writing code.

## The one boundary that matters

`PhonkJazzCore` is **pure Swift** — no `import AppKit`, no `import WebKit`. That
keeps the toggle, config, and URL logic testable without a display. GUI and
WebKit code live only in `Sources/PhonkJazz`. Keep new testable logic in Core.
There's an executable check for it:

```sh
grep -rn "import AppKit\|import WebKit" Sources/PhonkJazzCore/ && exit 1 || echo OK
```

## What can't be unit-tested

Audio playback, Google login, and the physical hotkey are GUI paths — a green
`make check` doesn't prove them. If your change touches the menubar, WebView, or
hotkey, actually run it (`make dev`), sign in, and confirm the behavior. "It
compiles" isn't done for those.

## Before you open a PR

1. `make check` passes — lint clean, build clean, tests green. CI runs the same gate.
2. If you touched a GUI/WebView/hotkey path, exercise it via `make dev` and say what you saw.
3. Don't delete a failing test to go green. Fix the cause or say why the test is wrong.
4. Keep commits atomic — one logical change each, message explaining *why*. History
   uses conventional prefixes (`feat:`, `fix:`, `chore:`, `docs:`); match that.
5. Never commit secrets or your YouTube/Google session — those live only in the
   WebView's data store, never the repo.

## Please ask first

Open an issue before spending real time on any of these — they change the
project's shape:

- Adding a SwiftPM dependency.
- Changing the default global shortcut.
- Persisting anything beyond the playlist config.
- Changing the config format or a new stack choice.

## Reporting bugs and asking for features

Open an [issue](https://github.com/Ibrahim925/phonk-jazz/issues). For a bug,
include your macOS version, Xcode/Swift version (`swift --version`), whether you
ran the `.app` or `make dev`, and what you expected versus what happened. If it's
about playback or sign-in, note whether the "Sign in / Show Player…" window
loaded YouTube Music logged-in.
