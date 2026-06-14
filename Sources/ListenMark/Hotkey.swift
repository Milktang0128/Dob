import AppKit
import Carbon.HIToolbox

/// Global hotkey via Carbon's RegisterEventHotKey. Unlike an NSEvent global
/// monitor, this fires system-wide WITHOUT requiring Accessibility permission,
/// so the trigger works even before the user grants access.
final class HotkeyManager {
    static let shared = HotkeyManager()
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var callbacks: [UInt32: () -> Void] = [:]
    private var handler: EventHandlerRef?

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hotKeyID)
            if status == noErr {
                HotkeyManager.shared.fire(hotKeyID.id)
            }
            return noErr
        }, 1, &spec, nil, &handler)
    }

    /// Carbon modifier mask = cmdKey | optionKey | controlKey | shiftKey.
    func register(id: UInt32, keyCode: UInt32, carbonModifiers: UInt32, onFire: @escaping () -> Void) {
        if let r = refs[id] { UnregisterEventHotKey(r); refs[id] = nil }
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4C534D4B), id: id) // 'LSMK'
        let status = RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            refs[id] = ref
            callbacks[id] = onFire
        }
    }

    func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs.removeAll()
        callbacks.removeAll()
    }

    private func fire(_ id: UInt32) {
        callbacks[id]?()
    }
}
