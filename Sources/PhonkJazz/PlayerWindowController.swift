import AppKit
import WebKit

/// A closable window that hosts the player's `WKWebView` so the user can sign
/// into Google / see what's playing. The WebView is owned by `PlayerController`
/// (not this window), so closing the window does not stop playback — the view is
/// simply moved out of it.
@MainActor
final class PlayerWindowController: NSWindowController {
    private let webView: WKWebView

    /// Wraps `webView` in a window sized for the YTM player.
    init(webView: WKWebView) {
        self.webView = webView
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "YouTube Music — sign in here"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Brings the player window to the front with the WebView attached.
    func present() {
        if let content = window?.contentView, webView.superview !== content {
            webView.frame = content.bounds
            webView.autoresizingMask = [.width, .height]
            content.addSubview(webView)
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
