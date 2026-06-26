import Cocoa
import Carbon

final class KeyRecorderView: NSView {
    var onRecorded: ((UInt32, UInt32) -> Void)?
    var onCleared: (() -> Void)?
    var representedAction: SnapAction?

    private var isRecording = false
    private var displayLabel: NSTextField!
    private var clearButton: NSButton!

    var currentModifiers: UInt32 = 0
    var currentKeyCode: UInt32 = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.cornerRadius = 6

        displayLabel = NSTextField(labelWithString: "")
        displayLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(displayLabel)

        clearButton = NSButton(title: "✕", target: self, action: #selector(clearShortcut))
        clearButton.bezelStyle = .inline
        clearButton.font = .systemFont(ofSize: 10)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.isHidden = true
        addSubview(clearButton)

        NSLayoutConstraint.activate([
            displayLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            displayLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            clearButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    var displayedText: String {
        displayLabel.stringValue
    }

    func setShortcut(_ hotkey: Hotkey?) {
        currentModifiers = hotkey?.modifiers ?? 0
        currentKeyCode = hotkey?.keyCode ?? 0
        renderCurrentShortcut()
    }

    override func mouseDown(with event: NSEvent) {
        if isRecording { cancelRecording() } else { beginRecording() }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        if event.keyCode == UInt16(kVK_Escape) { cancelRecording(); return }

        let modifiers = HotkeyFormatter.carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else { return }

        let keyCode = UInt32(event.keyCode)
        let hotkey = Hotkey(modifiers: modifiers, keyCode: keyCode)

        if let action = UserPreferences.shared.conflictingAction(for: hotkey, excluding: representedAction) {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Shortcut Conflict", comment: "")
            alert.informativeText = String(format: NSLocalizedString("This shortcut is already used by \"%@\".", comment: ""), action.displayName)
            alert.alertStyle = .warning
            alert.runModal()
            cancelRecording()
            return
        }

        currentModifiers = modifiers
        currentKeyCode = keyCode
        finishRecording(resumeHotkeys: false)
        onRecorded?(modifiers, keyCode)
        HotkeyManager.shared.resume()
    }

    override var acceptsFirstResponder: Bool { true }

    func beginRecording() {
        guard !isRecording else { return }
        isRecording = true
        HotkeyManager.shared.pause()
        displayLabel.stringValue = NSLocalizedString("Type shortcut...", comment: "")
        displayLabel.font = .systemFont(ofSize: 12)
        clearButton.isHidden = true
        layer?.borderColor = NSColor.white.cgColor
        layer?.borderWidth = 2
        window?.makeFirstResponder(self)
    }

    func cancelRecording() {
        finishRecording(resumeHotkeys: true)
    }

    private func finishRecording(resumeHotkeys: Bool) {
        guard isRecording else { return }
        isRecording = false
        displayLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1
        renderCurrentShortcut()
        if resumeHotkeys {
            HotkeyManager.shared.resume()
        }
    }

    @objc func clearShortcut() {
        currentModifiers = 0
        currentKeyCode = 0
        renderCurrentShortcut()
        onCleared?()
    }

    private func renderCurrentShortcut() {
        if currentModifiers == 0 {
            displayLabel.stringValue = ""
            clearButton.isHidden = true
        } else {
            displayLabel.stringValue = HotkeyFormatter.string(modifiers: currentModifiers, keyCode: currentKeyCode)
            clearButton.isHidden = false
        }
    }
}
