import Foundation

/// All JavaScript that drives the music.youtube.com player lives here.
///
/// YTM's DOM is not a stable contract — selectors change across redesigns. When
/// playback or the now-playing panel breaks, this is the one file to fix.
///
/// Source-of-truth order (measured against the live site, see
/// docs/ytmusic-integration.md): the `#movie_player` API first, then the HTML5
/// media element, then the player bar. The obvious choice — `<video>` — is not
/// reliable on its own: YTM feeds it a blob/MSE stream whose `duration` stays
/// `NaN` and `readyState` stays `0` while the page nonetheless reports
/// `paused === false`, so a media-element-only reading yields a frozen 0:00 and
/// an inverted play state.
enum YTMScript {
    /// Helpers shared by every snippet below.
    private static let helpers = """
        function pjPlayer() {
          var p = document.querySelector('#movie_player');
          return p && p.getPlayerState ? p : null;
        }
        function pjVideo() { return document.querySelector('video'); }
        function pjNumber(value) {
          var n = parseFloat(value);
          return isFinite(n) && n > 0 ? n : 0;
        }
        function pjTimes() {
          var v = pjVideo();
          if (v && isFinite(v.duration) && v.duration > 0) {
            return { time: pjNumber(v.currentTime), duration: v.duration };
          }
          var p = pjPlayer();
          if (p && p.getDuration) {
            try {
              var d = pjNumber(p.getDuration());
              if (d > 0) { return { time: pjNumber(p.getCurrentTime()), duration: d }; }
            } catch (e) {}
          }
          var bar = document.querySelector('#progress-bar');
          if (bar) {
            return {
              time: pjNumber(bar.getAttribute('aria-valuenow')),
              duration: pjNumber(bar.getAttribute('aria-valuemax'))
            };
          }
          return { time: 0, duration: 0 };
        }
        function pjIsPlaying() {
          var p = pjPlayer();
          if (p) {
            try {
              var s = p.getPlayerState();  // 1 playing, 3 buffering
              return s === 1 || s === 3;
            } catch (e) {}
          }
          var v = pjVideo();
          if (v) { return !v.paused && !v.ended; }
          var ms = navigator.mediaSession;
          return !!(ms && ms.playbackState === 'playing');
        }
        """

    /// Wraps `body` in an IIFE with the helpers in scope.
    private static func script(_ body: String) -> String {
        """
        (function () {
        \(helpers)
        \(body)
        })();
        """
    }

    /// Start/resume playback.
    static var play: String {
        script(
            """
            var p = pjPlayer();
            if (p && p.playVideo) { p.playVideo(); return 'api'; }
            var v = pjVideo();
            if (v && v.paused) {
              var r = v.play();
              if (r && r.catch) { r.catch(function () {}); }
              return 'video';
            }
            var b = document.querySelector('#play-pause-button, .play-pause-button');
            if (b) { b.click(); return 'button'; }
            return 'none';
            """)
    }

    /// Pause playback.
    static var pause: String {
        script(
            """
            var p = pjPlayer();
            if (p && p.pauseVideo) { p.pauseVideo(); return 'api'; }
            var v = pjVideo();
            if (v) { v.pause(); return 'video'; }
            var b = document.querySelector('#play-pause-button, .play-pause-button');
            if (b) { b.click(); return 'button'; }
            return 'none';
            """)
    }

    /// Toggle play/pause based on the player's real state.
    static var toggle: String {
        script(
            """
            var playing = pjIsPlaying();
            var p = pjPlayer();
            if (p) {
              if (playing) { p.pauseVideo(); } else { p.playVideo(); }
              return playing ? 'pause' : 'play';
            }
            var v = pjVideo();
            if (v) {
              if (playing) { v.pause(); } else { v.play(); }
              return playing ? 'pause' : 'play';
            }
            var b = document.querySelector('#play-pause-button, .play-pause-button');
            if (b) { b.click(); return 'button'; }
            return 'none';
            """)
    }

    /// Skip to the next track.
    static var next: String {
        script(
            """
            var b = document.querySelector(
              'tp-yt-paper-icon-button.next-button, .next-button, ytmusic-player-bar .next-button');
            if (b) { b.click(); return 'button'; }
            var p = pjPlayer();
            if (p && p.nextVideo) { p.nextVideo(); return 'api'; }
            return 'none';
            """)
    }

    /// Skip to the previous track.
    static var previous: String {
        script(
            """
            var b = document.querySelector(
              'tp-yt-paper-icon-button.previous-button, .previous-button, '
              + 'ytmusic-player-bar .previous-button');
            if (b) { b.click(); return 'button'; }
            var p = pjPlayer();
            if (p && p.previousVideo) { p.previousVideo(); return 'api'; }
            return 'none';
            """)
    }

    /// Jumps playback to `seconds` into the current track.
    ///
    /// `seekTo` is preferred over assigning `video.currentTime`, which silently
    /// does nothing while the media element is in its stalled MSE state.
    static func seek(to seconds: Double) -> String {
        script(
            """
            var target = Math.max(\(seconds), 0);
            var p = pjPlayer();
            if (p && p.seekTo) { p.seekTo(target, true); return 'api'; }
            var v = pjVideo();
            if (v && isFinite(v.duration)) {
              v.currentTime = Math.min(target, v.duration);
              return 'video';
            }
            return 'none';
            """)
    }

    /// Reads the current track as a JSON string matching `NowPlaying`.
    ///
    /// `navigator.mediaSession.metadata` is the primary text/artwork source: YTM
    /// populates it for the system now-playing UI, and it is far more stable than
    /// the player-bar DOM, which is only a fallback.
    static var nowPlaying: String {
        script(
            """
            var md = (navigator.mediaSession && navigator.mediaSession.metadata) || null;
            var title = md && md.title ? md.title : null;
            var artist = md && md.artist ? md.artist : null;
            var album = md && md.album ? md.album : null;
            var art = null;

            if (md && md.artwork && md.artwork.length) {
              var width = function (a) {
                return parseInt(((a && a.sizes) || '0x0').split('x')[0], 10) || 0;
              };
              var best = md.artwork[0];
              for (var i = 1; i < md.artwork.length; i++) {
                if (width(md.artwork[i]) > width(best)) { best = md.artwork[i]; }
              }
              art = best && best.src ? best.src : null;
            }

            if (!title) {
              var bar = document.querySelector('ytmusic-player-bar');
              var t = bar && bar.querySelector('.title');
              var by = bar && bar.querySelector('.byline');
              if (t) { title = t.textContent; }
              if (by) {
                // Byline reads "Artist • Album • Year"; a bare year isn't an album.
                var parts = by.textContent.split('•').map(function (s) { return s.trim(); });
                artist = artist || parts[0] || null;
                if (!album && parts[1] && !/^\\d{4}$/.test(parts[1])) { album = parts[1]; }
              }
            }

            if (!art) {
              var img = document.querySelector('ytmusic-player-bar img.image, #song-image img');
              if (img && img.src) { art = img.src; }
            }
            // Ask googleusercontent for a crisp size instead of the 60px thumbnail.
            if (art) { art = art.replace(/=w\\d+-h\\d+/, '=w320-h320'); }

            var times = pjTimes();
            return JSON.stringify({
              title: title || null,
              artist: artist || null,
              album: album || null,
              artworkURL: art,
              currentTime: times.time,
              duration: times.duration,
              isPlaying: pjIsPlaying()
            });
            """)
    }

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
