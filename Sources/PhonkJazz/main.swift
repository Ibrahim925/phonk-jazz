import AppKit
import PhonkJazzCore

// ---------------------------------------------------------------------------
// SCAFFOLD ONLY.
//
// This is the runnable skeleton the harness proves out — NOT the feature set.
// It launches as a menubar-only (accessory) app and shows a status item that
// reflects the current Mode, with a Quit action. That is all.
//
// The real features live in feature_list.json and are implemented in later
// sessions (embedded WKWebView for YouTube Music, JS playback control, the
// global Ctrl+Opt+Cmd+J hotkey, config persistence, settings window). Do not
// grow this file into those features ad hoc — add them as their own units.
// ---------------------------------------------------------------------------

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var mode: Mode = .jazz

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        render()

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Quit Phonk/Jazz",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        statusItem.menu = menu
    }

    private func render() {
        statusItem.button?.title = mode.shortLabel
    }
}

let app = NSApplication.shared
// Menubar-only: no Dock icon, no main window. Equivalent to LSUIElement, set
// programmatically so `swift run` behaves the same as the bundled .app.
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
