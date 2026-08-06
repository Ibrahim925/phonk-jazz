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
}
