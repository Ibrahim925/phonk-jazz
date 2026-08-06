import AppKit

/// Menubar-only YouTube Music toggle app. Entry point: install the app delegate,
/// which stands up the `AppController` (menubar, player, global hotkey, settings).
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = AppController()
    }
}

let app = NSApplication.shared
// Menubar-only: no Dock icon, no main window. Equivalent to LSUIElement, set
// programmatically so `swift run` behaves the same as the bundled .app.
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
