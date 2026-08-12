# YouTube Music Integration

> Read this when working on the WebView, login persistence, or JS playback control.

## The approach
There is no official YTM streaming API. The app embeds `music.youtube.com` in a
`WKWebView` and controls the real web player. The user signs into Google **once,
inside the app's WebView**; the session is persisted so later launches stay
logged in.

## Login persistence (critical)
Use a **persistent** website data store so cookies survive relaunch:

```swift
let config = WKWebViewConfiguration()
config.websiteDataStore = .default()  // persistent; NOT .nonPersistent()
```

- Never log or commit cookies / session tokens — they are the user's Google login.
- The WebView can live off-screen (add to an unshown window or a zero-alpha
  window) since playback continues without the view being visible.

## Google sign-in block (why a custom User-Agent is required)
Google refuses OAuth sign-in from embedded webviews and shows *"Couldn't sign
you in — this browser or app may not be secure. Try using a different browser"*
(listing Chrome/Firefox/Safari). This is NOT about the user's default browser; it
is Google detecting a `WKWebView`.

Fix: present a real **desktop Safari** User-Agent. `WKWebView` genuinely is
Safari's WebKit engine, so Google accepts it and login proceeds — with no
rendering quirks (unlike faking Chrome/Firefox on a WebKit engine).

```swift
webView.customUserAgent =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"
```

Set in `PlayerController.init`. Bump the `Version/` number when it drifts far
from current Safari. Verify propagation by reading `navigator.userAgent` back via
`evaluateJavaScript` — it must equal the string above.

## Playing a playlist
A YTM playlist URL looks like `https://music.youtube.com/playlist?list=<ID>`, but
navigating there only *shows* the playlist — its `<video>` element stays paused
with no source, so nothing plays. To actually start playback, navigate to the
**watch** URL `https://music.youtube.com/watch?list=<ID>`: YTM loads the player,
auto-selects the first track, and begins playing. (Verified against the live
site: playlist URL → `video.paused == true`; watch URL → `video.paused == false`.
Caveat, measured later: `paused == false` alone does **not** prove audio is
decoding — see the next section — so treat it as "the page intends to play".)
Use `YTMURL.watchURL(from:)` (Core) to convert.

## Reading state: do NOT trust the `<video>` element alone

Measured against the live site (headless `WKWebView`, logged out, 2026-08-11):
the page has exactly **one** `<video>`, fed a `blob:` MSE stream, and it reports

    duration: NaN   readyState: 0   currentTime: 0   paused: false

…indefinitely, while `navigator.mediaSession.playbackState` says `"playing"`.
So a media-element-only reading gives a seek bar frozen at `0:00 / --:--` and an
inverted play/pause state. `#movie_player` answered correctly at the same moment
(`getDuration() === 110`), and the player bar agreed (`#progress-bar`
`aria-valuemax="111"`, `.time-info` "0:00 / 1:51").

`YTMScript` therefore reads through helpers with a fixed precedence:

| Need | Order |
|---|---|
| position / duration | `<video>` when `duration` is finite -> `#movie_player.getCurrentTime()/getDuration()` -> `#progress-bar` aria values |
| playing? | `#movie_player.getPlayerState()` (1 playing, 3 buffering) -> `!video.paused && !video.ended` -> `mediaSession.playbackState` |
| play / pause / seek | `#movie_player.playVideo()/pauseVideo()/seekTo(s, true)` -> media element -> player-bar button |
| next / previous | player-bar `.next-button`/`.previous-button` -> `#movie_player.nextVideo()/previousVideo()` |

Assigning `video.currentTime` is a silent no-op in the stalled MSE state, which
is why seeking goes through `seekTo`. Verified live: `seekTo(30)` returned `api`
and the next read reported `currentTime: 30`.

## Track metadata (title / artist / album / artwork)

`navigator.mediaSession.metadata` is the primary source — YTM populates it for
the system now-playing UI and it survives redesigns far better than the DOM. The
player bar (`ytmusic-player-bar .title` / `.byline`) is the fallback; the byline
reads "Artist • Album • Year", so a bare 4-digit segment is not an album.
Artwork: pick the largest `md.artwork[]` entry by declared `sizes`.

Verified live: `{"title":"Vois Sur Ton Chemin","artist":"deprezz","duration":187}`.
Logged out, YTM inserts **ad** playback whose metadata appears in the media
session too (an ad title showed up before the first real track) — expected, and
one more reason the panel renders whatever the page reports rather than caching.

> Selectors on music.youtube.com are **not a stable contract** and change over
> time. Everything above is centralized in `Sources/PhonkJazz/YTMScript.swift`,
> so a YTM redesign is a one-file fix. Confirm against the live DOM when
> implementing.

## Autoplay
YTM may require a user gesture before audio can start. Options to evaluate during
implementation: trigger playback from within the WebView's own JS context, or
set `config.mediaTypesRequiringUserActionForPlayback = []` on the configuration.

## Memory (the WebView is a browser tab)
The native app is ~34 MB, but the `WKWebView` runs in a separate WebKit
`WebContent` process that can hit ~1 GB. The cost is **video decode** — YTM
always streams a video track (even "audio" mode is `ATV`, a still-image video),
and GPU/IOSurface frame buffers dominate the footprint (measured: RSS ~28 MB but
`phys_footprint` ~1.3 GB — the gap is GPU memory).

`YTMScript.preferAudioLowData` (applied after play + on a 15s timer, since radio
auto-advance resets it) cuts this by:
- Pinning `#movie_player` to `tiny` (144p) via `setPlaybackQualityRange`/
  `setPlaybackQuality` — shrinks decode buffers dramatically.
- On Premium, clicking `.song-button` inside `ytmusic-av-toggle` to select audio
  mode (guarded by `is-audio-playback-mode-selected` so it never selects video).

True *zero-video* requires the account setting **Settings → Playback → "Don't
play music videos when available"** (Premium) — flip it once in your account; the
web player then never fetches a video stream.

## Verifying (manual — GUI, not headless)
Playback and login can't be unit-tested headlessly. Verify via `make dev`:
1. Launch, sign into Google in the WebView, confirm YTM loads logged-in.
2. Fire the toggle; confirm the correct playlist starts and audio plays.
3. Quit and relaunch; confirm still logged in (no re-auth).
