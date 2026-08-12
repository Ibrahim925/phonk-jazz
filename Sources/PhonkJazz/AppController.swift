import AppKit
import Carbon.HIToolbox
import PhonkJazzCore

/// The app's brain. Owns the current `Mode` and config, the menubar status item,
/// the embedded player, the global hotkey, and the settings window; routes every
/// user intent (hotkey, menu, settings) onto the player and status item.
@MainActor
final class AppController: NSObject {
    private let store = ConfigStore()
    private var config: AppConfig
    private var mode: Mode = .jazz
    private var isPlaying = false

    private let player = PlayerController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let hotKeys = HotKeyCenter()
    private var settings: SettingsWindowController?
    private var playerWindow: PlayerWindowController?

    override init() {
        config = store.load()
        super.init()

        buildMenu()
        render()

        // Preload the current mode's playlist (no autoplay) so the first toggle
        // is responsive. Keep the WebView off-screen — audio plays regardless.
        player.load(config.playlistURL(for: mode), autoplay: false)

        applyHotKeys()
    }

    // MARK: - Intents

    /// Flip jazz<->phonk: load the other playlist and start playing it.
    func toggleMode() {
        mode = mode.toggled
        player.load(config.playlistURL(for: mode), autoplay: true)
        isPlaying = true
        render()
    }

    @objc private func toggleModeAction() { toggleMode() }

    /// Toggles playback of whatever is loaded.
    func togglePlayPause() {
        player.togglePlayPause()
        isPlaying.toggle()
        render()
    }

    @objc private func playPauseAction() { togglePlayPause() }

    @objc private func openSettingsAction() {
        let controller = SettingsWindowController(config: config)
        controller.onSave = { [weak self] newConfig in
            guard let self else { return }
            self.config = newConfig
            try? self.store.save(newConfig)
            // Reflect the edit immediately if we're currently playing.
            self.player.load(newConfig.playlistURL(for: self.mode), autoplay: self.isPlaying)
            self.applyHotKeys()
        }
        settings = controller
        controller.present()
    }

    @objc private func showPlayerAction() {
        if playerWindow == nil {
            playerWindow = PlayerWindowController(webView: player.webView)
        }
        playerWindow?.present()
    }

    // MARK: - Shortcuts

    /// (Re)registers both global shortcuts from the current config. Called at
    /// launch and after Settings saves, so a rebind is live immediately.
    ///
    /// A combination another app already owns can't be registered; tell the user
    /// rather than leaving a dead key.
    private func applyHotKeys() {
        let rejected = hotKeys.apply([
            .toggleMode: (config.toggleShortcut, { [weak self] in self?.toggleMode() }),
            .playPause: (config.playPauseShortcut, { [weak self] in self?.togglePlayPause() }),
        ])
        guard !rejected.isEmpty else { return }

        let names = rejected.map { binding -> String in
            switch binding {
            case .toggleMode: return "Toggle (\(config.toggleShortcut.displayString))"
            case .playPause: return "Play/Pause (\(config.playPauseShortcut.displayString))"
            }
        }
        let alert = NSAlert()
        alert.messageText = "Shortcut unavailable"
        alert.informativeText =
            "macOS refused to register: \(names.joined(separator: ", ")).\n\n"
            + "Another app is probably using that combination. Pick a different one in Settings."
        alert.runModal()
    }

    // MARK: - UI

    private func buildMenu() {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Toggle Jazz / Phonk", action: #selector(toggleModeAction),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: "Play / Pause", action: #selector(playPauseAction), keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Sign in / Show Player…", action: #selector(showPlayerAction),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Settings…", action: #selector(openSettingsAction), keyEquivalent: ","
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Phonk/Jazz", action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
    }

    private func render() {
        let glyph = isPlaying ? "▶" : "❚❚"
        statusItem.button?.title = "\(mode.shortLabel) \(glyph)"
    }
}
