import Foundation

/// All JavaScript that drives the music.youtube.com player lives here.
///
/// YTM's DOM is not a stable contract — selectors change across redesigns. When
/// playback breaks, this is the one file to fix. We prefer the HTML5 media
/// element (stable) and fall back to the player-bar button.
enum YTMScript {
    /// Start/resume playback. Tries the media element, then the play button.
    static let play = """
        (function () {
          var v = document.querySelector('video');
          if (v && v.paused) { var p = v.play(); if (p && p.catch) { p.catch(function () {}); } return 'video'; }
          if (v) { return 'already'; }
          var b = document.querySelector('#play-pause-button, tp-yt-paper-icon-button.play-pause-button, ytmusic-play-button-renderer');
          if (b) { b.click(); return 'button'; }
          return 'none';
        })();
        """

    /// Pause playback.
    static let pause = """
        (function () {
          var v = document.querySelector('video');
          if (v) { v.pause(); return 'video'; }
          return 'none';
        })();
        """

    /// Toggle play/pause based on the media element's current state.
    static let toggle = """
        (function () {
          var v = document.querySelector('video');
          if (v) { if (v.paused) { v.play(); return 'play'; } else { v.pause(); return 'pause'; } }
          var b = document.querySelector('#play-pause-button, tp-yt-paper-icon-button.play-pause-button');
          if (b) { b.click(); return 'button'; }
          return 'none';
        })();
        """

    /// Cuts the WebView's memory footprint: forces the player to the smallest
    /// video resolution and, on Premium, switches the Song/Video toggle to
    /// audio. YTM always streams a video track (even "audio" mode is a
    /// still-image video), so decode buffers are the memory hog; pinning to
    /// `tiny` shrinks them from ~1080p to ~144p. Idempotent and safe to run on a
    /// timer: it only ever *selects* audio (never video) and no-ops when the
    /// player/toggle aren't present. Verified selectors against the live DOM
    /// (2026-08-06): `#movie_player` quality API + `.song-button` in
    /// `ytmusic-av-toggle`.
    static let preferAudioLowData = """
        (function () {
          var out = [];
          var mp = document.getElementById('movie_player');
          if (mp && mp.setPlaybackQualityRange) { mp.setPlaybackQualityRange('tiny', 'tiny'); out.push('range'); }
          if (mp && mp.setPlaybackQuality) { mp.setPlaybackQuality('tiny'); out.push('quality'); }
          var t = document.querySelector('ytmusic-av-toggle');
          if (t && t.getAttribute('is-audio-playback-mode-selected') !== 'true') {
            var song = t.querySelector('.song-button');
            if (song) { song.click(); out.push('audio'); }
          }
          return out.join(',') || 'noop';
        })();
        """
}
