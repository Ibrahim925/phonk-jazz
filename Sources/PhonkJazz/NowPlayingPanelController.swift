import AppKit
import PhonkJazzCore

/// The panel shown when the menubar icon is clicked: album art, track text, a
/// seek bar, transport controls, and the commands that used to live in the
/// status item's menu.
///
/// Deliberately dumb — it renders a `NowPlaying` snapshot and emits `Command`s.
/// `AppController` remains the only thing that talks to the player, so the panel
/// never has to know how playback works.
@MainActor
final class NowPlayingPanelController: NSViewController {
    /// A user intent raised from the panel.
    enum Command {
        /// Toggle playback.
        case playPause
        /// Skip forward one track.
        case next
        /// Skip back one track.
        case previous
        /// Jump to an absolute position, in seconds.
        case seek(Double)
        /// Flip jazz <-> phonk.
        case toggleMode
        /// Surface the YTM WebView (sign-in).
        case showPlayer
        /// Open Settings.
        case settings
        /// Quit the app.
        case quit
    }

    /// Called with each intent the user raises.
    var onCommand: (Command) -> Void = { _ in }

    private let artworkView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let elapsedLabel = NSTextField(labelWithString: "0:00")
    private let durationLabel = NSTextField(labelWithString: "--:--")
    private let seekSlider = NSSlider()
    private let previousButton = NSButton()
    private let playPauseButton = NSButton()
    private let nextButton = NSButton()
    private let modeButton = NSButton()
    private let moreButton = NSButton()

    private var track = NowPlaying()
    private var loadedArtworkURL: String?
    private var artworkTask: URLSessionDataTask?
    /// True while the user drags the seek bar, so polling can't yank the thumb.
    private var isScrubbing = false

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 186))
        buildLayout()
        render(track, mode: .jazz)
    }

    // MARK: - Rendering

    /// Renders a snapshot. Ignored mid-scrub for the seek bar only, so dragging
    /// stays smooth while the text keeps updating.
    func render(_ track: NowPlaying, mode: Mode) {
        self.track = track

        titleLabel.stringValue = track.displayTitle
        subtitleLabel.stringValue = track.displaySubtitle
        subtitleLabel.isHidden = track.displaySubtitle.isEmpty
        durationLabel.stringValue = track.durationText
        modeButton.title = mode == .jazz ? "Jazz" : "Phonk"

        playPauseButton.image = symbol(track.isPlaying ? "pause.fill" : "play.fill")
        playPauseButton.toolTip = track.isPlaying ? "Pause" : "Play"

        if !isScrubbing {
            elapsedLabel.stringValue = track.elapsedText
            seekSlider.doubleValue = track.progress
        }
        seekSlider.isEnabled = track.duration > 0
        loadArtwork(track.artworkURL)
    }

    /// Puts the current bindings in the tooltips so the panel teaches them.
    func showShortcuts(toggle: Shortcut, playPause: Shortcut) {
        modeButton.toolTip = "Toggle Jazz / Phonk (\(toggle.displayString))"
        playPauseButton.toolTip = "Play / Pause (\(playPause.displayString))"
    }

    private func loadArtwork(_ urlString: String?) {
        guard let urlString, let url = URL(string: urlString) else {
            if track.artworkURL == nil {
                artworkTask?.cancel()
                loadedArtworkURL = nil
                artworkView.image = symbol("music.note")
            }
            return
        }
        guard urlString != loadedArtworkURL else { return }  // same art: don't refetch

        loadedArtworkURL = urlString
        artworkTask?.cancel()
        artworkTask = URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async { [weak self] in
                guard self?.loadedArtworkURL == urlString else { return }
                self?.artworkView.image = image
            }
        }
        artworkTask?.resume()
    }

    // MARK: - Actions

    @objc private func playPauseTapped() { onCommand(.playPause) }
    @objc private func nextTapped() { onCommand(.next) }
    @objc private func previousTapped() { onCommand(.previous) }
    @objc private func modeTapped() { onCommand(.toggleMode) }

    /// NSSlider has no drag-ended callback, so the current event distinguishes
    /// "still dragging" (update the label only) from "let go" (commit the seek).
    @objc private func seekChanged() {
        let target = track.time(forProgress: seekSlider.doubleValue)
        elapsedLabel.stringValue = NowPlaying.timeText(target)

        if NSApp.currentEvent?.type == .leftMouseUp {
            isScrubbing = false
            onCommand(.seek(target))
        } else {
            isScrubbing = true
        }
    }

    @objc private func moreTapped() {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Sign in / Show Player…", action: #selector(showPlayerTapped),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Settings…", action: #selector(settingsTapped), keyEquivalent: ","
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Phonk/Jazz", action: #selector(quitTapped), keyEquivalent: "q"
        )
        .target = self
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: moreButton.bounds.height), in: moreButton)
    }

    @objc private func showPlayerTapped() { onCommand(.showPlayer) }
    @objc private func settingsTapped() { onCommand(.settings) }
    @objc private func quitTapped() { onCommand(.quit) }

    // MARK: - Layout

    private func buildLayout() {
        artworkView.wantsLayer = true
        artworkView.layer?.cornerRadius = 6
        artworkView.layer?.masksToBounds = true
        artworkView.imageScaling = .scaleProportionallyUpOrDown
        artworkView.image = symbol("music.note")
        artworkView.contentTintColor = .secondaryLabelColor

        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 2
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail

        for label in [elapsedLabel, durationLabel] {
            label.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
            label.textColor = .secondaryLabelColor
        }

        seekSlider.minValue = 0
        seekSlider.maxValue = 1
        seekSlider.isContinuous = true
        seekSlider.controlSize = .small
        seekSlider.target = self
        seekSlider.action = #selector(seekChanged)

        configure(previousButton, symbolName: "backward.fill", action: #selector(previousTapped))
        configure(playPauseButton, symbolName: "play.fill", action: #selector(playPauseTapped))
        configure(nextButton, symbolName: "forward.fill", action: #selector(nextTapped))
        configure(moreButton, symbolName: "ellipsis.circle", action: #selector(moreTapped))
        previousButton.toolTip = "Previous track"
        nextButton.toolTip = "Next track"
        moreButton.toolTip = "More commands"

        modeButton.bezelStyle = .rounded
        modeButton.controlSize = .small
        modeButton.target = self
        modeButton.action = #selector(modeTapped)
        modeButton.translatesAutoresizingMaskIntoConstraints = false

        let transport = NSStackView(views: [previousButton, playPauseButton, nextButton])
        transport.spacing = 18
        transport.alignment = .centerY
        transport.translatesAutoresizingMaskIntoConstraints = false

        for subview in [
            artworkView, titleLabel, subtitleLabel, seekSlider, elapsedLabel, durationLabel,
            transport, modeButton, moreButton,
        ] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 320),

            artworkView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            artworkView.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            artworkView.widthAnchor.constraint(equalToConstant: 64),
            artworkView.heightAnchor.constraint(equalToConstant: 64),

            titleLabel.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            titleLabel.topAnchor.constraint(equalTo: artworkView.topAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),

            seekSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            seekSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            seekSlider.topAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: 12),

            elapsedLabel.leadingAnchor.constraint(equalTo: seekSlider.leadingAnchor),
            elapsedLabel.topAnchor.constraint(equalTo: seekSlider.bottomAnchor, constant: 1),
            durationLabel.trailingAnchor.constraint(equalTo: seekSlider.trailingAnchor),
            durationLabel.centerYAnchor.constraint(equalTo: elapsedLabel.centerYAnchor),

            transport.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            transport.topAnchor.constraint(equalTo: elapsedLabel.bottomAnchor, constant: 10),
            transport.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),

            modeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            modeButton.centerYAnchor.constraint(equalTo: transport.centerYAnchor),
            moreButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            moreButton.centerYAnchor.constraint(equalTo: transport.centerYAnchor),
        ])
    }

    private func configure(_ button: NSButton, symbolName: String, action: Selector) {
        button.image = symbol(symbolName)
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.bezelStyle = .accessoryBar
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    private func symbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: name)?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .medium))
    }
}
