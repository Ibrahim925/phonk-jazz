import PhonkJazzCore
import WebKit

/// Owns the off-screen `WKWebView` that hosts the YouTube Music web player and
/// drives it via injected JavaScript. Login persists via the default (on-disk)
/// website data store, so the user signs into Google only once.
@MainActor
final class PlayerController: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    private var autoplayAfterLoad = false
    private var autoplayAttempts = 0

    /// Desktop Safari User-Agent. Google refuses to sign you in from an embedded
    /// webview ("this browser or app may not be secure — use a supported
    /// browser"). Presenting a real Safari UA makes Google treat the WebView as
    /// Safari (which it genuinely is — same WebKit engine), so login proceeds.
    /// Bump the Version/ number occasionally to track current Safari.
    private static let safariUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"

    private var optimizeTimer: Timer?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()  // persistent: keeps the login
        configuration.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.customUserAgent = Self.safariUserAgent
        // Radio auto-advances to new tracks, which reset video quality to `auto`.
        // Re-apply the low-data/audio optimization on a light timer so memory
        // stays down across track changes. No-ops when nothing is playing.
        optimizeTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) {
            [weak self] _ in
            self?.applyAudioOptimizations()
        }
    }

    deinit { optimizeTimer?.invalidate() }

    /// Pins the player to the lowest video quality (and audio mode on Premium) to
    /// cut the WebView's video-decode memory. Safe to call repeatedly.
    func applyAudioOptimizations() {
        webView.evaluateJavaScript(YTMScript.preferAudioLowData, completionHandler: nil)
    }

    /// Loads a playlist. When `autoplay` is true the URL is converted to a YTM
    /// *watch* URL (which actually starts playback) and play is reinforced once
    /// the page loads; when false the playlist page loads silently (no autostart),
    /// used to warm the WebView without making noise on launch.
    func load(_ urlString: String, autoplay: Bool) {
        let target = autoplay ? YTMURL.watchURL(from: urlString) : urlString
        guard let url = URL(string: target) else { return }
        autoplayAfterLoad = autoplay
        webView.load(URLRequest(url: url))
    }

    /// Starts/resumes playback immediately.
    func play() {
        webView.evaluateJavaScript(YTMScript.play, completionHandler: nil)
    }

    /// Pauses playback.
    func pause() {
        webView.evaluateJavaScript(YTMScript.pause, completionHandler: nil)
    }

    /// Toggles play/pause based on the player's current state.
    func togglePlayPause() {
        webView.evaluateJavaScript(YTMScript.toggle, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard autoplayAfterLoad else { return }
        autoplayAttempts = 0
        attemptAutoplay()
    }

    // YTM builds its player after `didFinish`; retry a handful of times so the
    // first play actually lands, and pin low-data/audio on each pass.
    private func attemptAutoplay() {
        guard autoplayAfterLoad, autoplayAttempts < 6 else { return }
        autoplayAttempts += 1
        play()
        applyAudioOptimizations()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.attemptAutoplay()
        }
    }
}
