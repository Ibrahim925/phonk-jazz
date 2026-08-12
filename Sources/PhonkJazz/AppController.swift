import AppKit
import PhonkJazzCore

/// The app's brain. Owns the current `Mode` and config, the menubar status item,
/// the now-playing panel, the embedded player, the global shortcuts, and the
/// settings window; routes every user intent (shortcut, panel, settings) onto the
/// player and status item.
@MainActor
final class AppController: NSObject, NSPopoverDelegate {
    private let store = ConfigStore()
    private var config: AppConfig
    private var mode: Mode = .jazz
    private var isPlaying = false

    private let player = PlayerController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let hotKeys = HotKeyCenter()
    private var settings: SettingsWindowController?
    private var playerWindow: PlayerWindowController?

    private let panel = NowPlayingPanelController()
    private let popover = NSPopover()
    /// Polls the page for track/position while the panel is open, and only then.
    private var pollTimer: Timer?

    override init() {
        config = store.load()
        super.init()

        buildStatusItem()
        buildPanel()
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
        refreshSoon()
    }

    /// Toggles playback of whatever is loaded.
    func togglePlayPause() {
        player.togglePlayPause()
        isPlaying.toggle()
        render()
        refreshSoon()
    }

    private func openSettings() {
        let controller = SettingsWindowController(config: config)
        controller.onSave = { [weak self] newConfig in
            guard let self else { return }
            self.config = newConfig
            try? self.store.save(newConfig)
            // Reflect the edit immediately if we're currently playing.
            self.player.load(newConfig.playlistURL(for: self.mode), autoplay: self.isPlaying)
            self.applyHotKeys()
            self.panel.showShortcuts(
                toggle: newConfig.toggleShortcut, playPause: newConfig.playPauseShortcut)
        }
        settings = controller
        controller.present()
    }

    private func showPlayerWindow() {
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

    // MARK: - Panel

    private func buildStatusItem() {
        // No `statusItem.menu`: assigning one makes AppKit swallow the click and
        // open the menu, which would leave the panel unreachable.
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func buildPanel() {
        popover.contentViewController = panel
        popover.behavior = .transient
        popover.delegate = self
        panel.showShortcuts(toggle: config.toggleShortcut, playPause: config.playPauseShortcut)
        panel.onCommand = { [weak self] command in self?.handle(command) }
    }

    private func handle(_ command: NowPlayingPanelController.Command) {
        switch command {
        case .playPause: togglePlayPause()
        case .next:
            player.next()
            refreshSoon()
        case .previous:
            player.previous()
            refreshSoon()
        case .seek(let seconds):
            player.seek(to: seconds)
            refreshNowPlaying()
        case .toggleMode: toggleMode()
        case .showPlayer:
            popover.performClose(nil)
            showPlayerWindow()
        case .settings:
            popover.performClose(nil)
            openSettings()
        case .quit: NSApp.terminate(nil)
        }
    }

    @objc private func statusItemClicked() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        refreshNowPlaying()
        startPolling()
    }

    /// Stop polling as soon as the panel goes away — a menubar app has no business
    /// waking twice a second while nobody is looking at it.
    func popoverDidClose(_ notification: Notification) {
        stopPolling()
    }

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshNowPlaying() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Reads the page and re-renders. The page is the source of truth for whether
    /// audio is actually playing, so this also corrects our optimistic guess.
    private func refreshNowPlaying() {
        player.fetchNowPlaying { [weak self] track in
            guard let self else { return }
            if !track.isEmpty || track.duration > 0 {
                self.isPlaying = track.isPlaying
            }
            self.panel.render(track, mode: self.mode)
            self.render()
        }
    }

    /// Re-read shortly after an action: YTM applies play/pause/skip
    /// asynchronously, so an immediate read would report the old state.
    private func refreshSoon() {
        guard popover.isShown else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refreshNowPlaying()
        }
    }

    // MARK: - UI

    private func render() {
        let glyph = isPlaying ? "▶" : "❚❚"
        statusItem.button?.title = "\(mode.shortLabel) \(glyph)"
    }
}
