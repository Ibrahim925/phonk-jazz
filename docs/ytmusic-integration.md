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

## Playing a playlist
A YTM playlist URL looks like `https://music.youtube.com/playlist?list=<PLAYLIST_ID>`.
To switch playlists, navigate the WebView to that URL, then start playback. The
web player exposes an HTML5 `<video>`/`<audio>` element and on-page controls;
drive them with `evaluateJavaScript`:

```swift
// Start / resume playback (illustrative — verify selectors against the live DOM)
webView.evaluateJavaScript("document.querySelector('video')?.play()")
// Play/pause toggle via the player bar button is more robust than raw media API:
//   document.querySelector('#play-pause-button')?.click()
```

> Selectors on music.youtube.com are **not a stable contract** and change over
> time. Prefer the media element (`document.querySelector('video')`) and the
> player-bar play/pause control; centralize all selectors in one place so a YTM
> redesign is a one-file fix. Confirm against the live DOM when implementing.

## Autoplay
YTM may require a user gesture before audio can start. Options to evaluate during
implementation: trigger playback from within the WebView's own JS context, or
set `config.mediaTypesRequiringUserActionForPlayback = []` on the configuration.

## Verifying (manual — GUI, not headless)
Playback and login can't be unit-tested headlessly. Verify via `make dev`:
1. Launch, sign into Google in the WebView, confirm YTM loads logged-in.
2. Fire the toggle; confirm the correct playlist starts and audio plays.
3. Quit and relaunch; confirm still logged in (no re-auth).
