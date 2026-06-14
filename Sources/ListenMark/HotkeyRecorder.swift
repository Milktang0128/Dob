import SwiftUI
import AppKit
import Carbon.HIToolbox

/// A button that, when clicked, records the next modifier+key combo.
struct HotkeyRecorder: NSViewRepresentable {
    @Binding var display: String
    var onRecord: (UInt16, NSEvent.ModifierFlags, String) -> Void

    func makeNSView(context: Context) -> RecorderContainer {
        let view = RecorderContainer()
        view.recorder.onRecord = onRecord
        view.recorder.onRecordingChanged = { [weak view] recording in
            view?.setRecording(recording)
        }
        view.recorder.title = display
        return view
    }

    func updateNSView(_ nsView: RecorderContainer, context: Context) {
        nsView.recorder.onRecord = onRecord
        if !nsView.recorder.recording { nsView.recorder.title = display }
    }
}

final class RecorderContainer: NSView {
    let recorder = RecorderButton()
    private let cancelButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        recorder.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .circular
        cancelButton.setButtonType(.momentaryPushIn)
        cancelButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: AppFlavor.text("取消录制", "Cancel recording"))
        cancelButton.imageScaling = .scaleProportionallyDown
        cancelButton.isBordered = false
        cancelButton.contentTintColor = .tertiaryLabelColor
        cancelButton.target = self
        cancelButton.action = #selector(cancelRecording)
        cancelButton.toolTip = AppFlavor.text("取消录制", "Cancel recording")
        cancelButton.isHidden = true

        addSubview(recorder)
        addSubview(cancelButton)

        NSLayoutConstraint.activate([
            recorder.leadingAnchor.constraint(equalTo: leadingAnchor),
            recorder.topAnchor.constraint(equalTo: topAnchor),
            recorder.bottomAnchor.constraint(equalTo: bottomAnchor),
            cancelButton.leadingAnchor.constraint(equalTo: recorder.trailingAnchor, constant: 6),
            cancelButton.centerYAnchor.constraint(equalTo: recorder.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 18),
            cancelButton.heightAnchor.constraint(equalToConstant: 18),
            cancelButton.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: recorder.intrinsicContentSize.width + 24, height: recorder.intrinsicContentSize.height)
    }

    func setRecording(_ recording: Bool) {
        cancelButton.isHidden = !recording
        invalidateIntrinsicContentSize()
    }

    @objc private func cancelRecording() {
        recorder.cancelRecording()
    }
}

final class RecorderButton: NSButton {
    var onRecord: ((UInt16, NSEvent.ModifierFlags, String) -> Void)?
    var onRecordingChanged: ((Bool) -> Void)?
    var recording = false
    private var monitor: Any?
    private var previousTitle = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(begin)
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { stop() }

    @objc private func begin() {
        guard !recording else { return }
        previousTitle = title
        recording = true
        title = AppFlavor.text("按下新快捷键…", "Press new hotkey...")
        onRecordingChanged?(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            self?.capture(e)
            return nil
        }
    }

    private func capture(_ e: NSEvent) {
        if e.keyCode == 53 {
            cancelRecording()
            return
        }
        let mods = e.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !mods.isEmpty else { NSSound.beep(); return } // require a modifier
        let chars = (e.charactersIgnoringModifiers ?? "").uppercased()
        guard !chars.isEmpty else { NSSound.beep(); return }
        let disp = Self.symbols(mods) + chars
        title = disp
        stop()
        onRecord?(e.keyCode, mods, disp)
    }

    func cancelRecording() {
        title = previousTitle
        stop()
    }

    private func stop() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        onRecordingChanged?(false)
    }

    static func symbols(_ m: NSEvent.ModifierFlags) -> String {
        var s = ""
        if m.contains(.control) { s += "⌃" }
        if m.contains(.option) { s += "⌥" }
        if m.contains(.shift) { s += "⇧" }
        if m.contains(.command) { s += "⌘" }
        return s
    }
}

/// NSEvent modifier flags → Carbon modifier mask for RegisterEventHotKey.
func carbonModifiers(_ f: NSEvent.ModifierFlags) -> Int {
    var m = 0
    if f.contains(.command) { m |= cmdKey }
    if f.contains(.option) { m |= optionKey }
    if f.contains(.control) { m |= controlKey }
    if f.contains(.shift) { m |= shiftKey }
    return m
}
