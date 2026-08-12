import Carbon.HIToolbox
import Foundation
import PhonkJazzCore

/// Owns every system-wide hotkey the app registers.
///
/// Carbon hotkeys fire globally without the Accessibility permission a global
/// `NSEvent` monitor would require — lower install friction for a background
/// menubar utility.
///
/// Why a single center instead of one object per hotkey: Carbon delivers hotkey
/// events to *every* handler installed on the application event target, so N
/// independent handlers means each one runs for all N hotkeys. This type
/// installs exactly one handler and routes on the `EventHotKeyID` carried by the
/// event, which is also what makes rebinding safe — bindings are replaced
/// wholesale via `apply(_:)`.
///
/// Main-thread only: actions are delivered on the main queue.
final class HotKeyCenter {
    /// Which app intent a registered hotkey triggers.
    enum Binding: UInt32 {
        /// Flip jazz <-> phonk.
        case toggleMode = 1
        /// Toggle play/pause.
        case playPause = 2
    }

    private var actions: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?

    /// Installs the one shared Carbon event handler.
    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData, let event else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return noErr }
                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { center.fire(hotKeyID.id) }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }

    /// Replaces all bindings with `bindings`, returning the ones the system
    /// refused (already claimed by another app, or invalid).
    ///
    /// Called on launch and again after Settings saves, so a rebind takes effect
    /// without a relaunch.
    @discardableResult
    func apply(_ bindings: [Binding: (shortcut: Shortcut, action: () -> Void)]) -> [Binding] {
        unregisterAll()
        var rejected: [Binding] = []
        for (binding, entry) in bindings {
            if register(entry.shortcut, as: binding, action: entry.action) { continue }
            rejected.append(binding)
        }
        return rejected
    }

    /// Registers one shortcut. Returns false if it is invalid or unavailable.
    @discardableResult
    func register(_ shortcut: Shortcut, as binding: Binding, action: @escaping () -> Void) -> Bool {
        guard shortcut.isValid else { return false }
        var ref: EventHotKeyRef?
        // Signature 'PJHK' scopes the ids to this app.
        let hotKeyID = EventHotKeyID(signature: OSType(0x504A_484B), id: binding.rawValue)
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            Self.carbonModifiers(shortcut.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }
        refs[binding.rawValue] = ref
        actions[binding.rawValue] = action
        return true
    }

    /// Releases every registered hotkey.
    func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs.removeAll()
        actions.removeAll()
    }

    private func fire(_ id: UInt32) {
        actions[id]?()
    }

    /// Translates our pure modifier flags into Carbon's mask.
    private static func carbonModifiers(_ modifiers: ModifierKeys) -> UInt32 {
        var mask = 0
        if modifiers.contains(.control) { mask |= controlKey }
        if modifiers.contains(.option) { mask |= optionKey }
        if modifiers.contains(.command) { mask |= cmdKey }
        if modifiers.contains(.shift) { mask |= shiftKey }
        return UInt32(mask)
    }

    deinit {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
