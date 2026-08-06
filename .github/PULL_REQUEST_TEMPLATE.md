<!-- Keep it short. Link the issue if there is one. -->

## What & why

<!-- What does this change, and what problem does it solve? -->

## How I verified

<!-- `make check` output, and — if this touches the menubar, WebView, hotkey, or
     playback — the real path you exercised via `make dev` (signed in, toggled). -->

## Checklist

- [ ] `make check` passes (lint + build + tests).
- [ ] `PhonkJazzCore` stayed pure — no `import AppKit` / `import WebKit` in it.
- [ ] GUI/audio/hotkey change? I ran it and confirmed the behavior.
- [ ] No secrets or session data committed.
- [ ] For a dependency, the default shortcut, the config format, or a stack
      change: I opened an issue to discuss it first.
