import Carbon.HIToolbox
import Foundation

/// A single system-wide hotkey registered via Carbon `RegisterEventHotKey`.
///
/// Carbon hotkeys fire globally without the Accessibility permission that a
/// global `NSEvent` monitor would require — lower install friction for a
/// background menubar utility.
final class GlobalHotKey {
    /// Invoked on the main thread each time the hotkey is pressed.
    var onFire: () -> Void = {}

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    /// Registers the hotkey for the given Carbon virtual `keyCode` and modifier
    /// mask (e.g. `controlKey | optionKey | cmdKey`).
    init(keyCode: UInt32, modifiers: UInt32) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { hotKey.onFire() }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x504A_484B), id: 1)  // 'PJHK'
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
