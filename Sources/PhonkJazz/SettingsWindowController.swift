import AppKit
import PhonkJazzCore

/// A small settings window for editing the two playlist URLs. Validates input
/// before handing a new `AppConfig` back to the caller via `onSave`.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    /// Called with the validated, saved config when the user clicks Save.
    var onSave: (AppConfig) -> Void = { _ in }

    private let jazzField = NSTextField()
    private let phonkField = NSTextField()

    /// Builds the window pre-filled from `config`.
    init(config: AppConfig) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 170),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Phonk/Jazz Settings"
        super.init(window: window)
        window.delegate = self
        buildLayout(in: window, config: config)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Brings the settings window to the front (menubar apps aren't active by default).
    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildLayout(in window: NSWindow, config: AppConfig) {
        let content = window.contentView!

        let jazzLabel = makeLabel("Jazz playlist URL")
        let phonkLabel = makeLabel("Phonk playlist URL")
        jazzField.stringValue = config.jazzURL
        phonkField.stringValue = config.phonkURL
        for field in [jazzField, phonkField] {
            field.translatesAutoresizingMaskIntoConstraints = false
            field.lineBreakMode = .byTruncatingTail
        }

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        for button in [saveButton, cancelButton] {
            button.bezelStyle = .rounded
            button.translatesAutoresizingMaskIntoConstraints = false
        }

        for view in [jazzLabel, jazzField, phonkLabel, phonkField, saveButton, cancelButton] {
            content.addSubview(view)
        }

        NSLayoutConstraint.activate([
            jazzLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            jazzLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            jazzField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            jazzField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            jazzField.topAnchor.constraint(equalTo: jazzLabel.bottomAnchor, constant: 4),

            phonkLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            phonkLabel.topAnchor.constraint(equalTo: jazzField.bottomAnchor, constant: 12),
            phonkField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            phonkField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            phonkField.topAnchor.constraint(equalTo: phonkLabel.bottomAnchor, constant: 4),

            saveButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),
            cancelButton.trailingAnchor.constraint(
                equalTo: saveButton.leadingAnchor, constant: -10),
            cancelButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),
        ])
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    @objc private func save() {
        let jazz = jazzField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let phonk = phonkField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        for value in [jazz, phonk] where !AppConfig.isValidPlaylistURL(value) {
            let alert = NSAlert()
            alert.messageText = "Invalid playlist URL"
            alert.informativeText =
                "Each URL must be a music.youtube.com playlist link containing 'list='.\n\nNot valid: \(value)"
            alert.runModal()
            return
        }
        onSave(AppConfig(jazzURL: jazz, phonkURL: phonk))
        close()
    }

    @objc private func cancel() {
        close()
    }
}
