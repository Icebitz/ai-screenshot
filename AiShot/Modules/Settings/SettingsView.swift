import SwiftUI
import Carbon
import AppKit

struct SettingsView: View {
    @State private var hotKeyCode: Int = Int(kVK_ANSI_0)
    @State private var hotKeyCommand: Bool = true
    @State private var hotKeyShift: Bool = true
    @State private var hotKeyOption: Bool = false
    @State private var hotKeyControl: Bool = false
    @State private var captureCursor: Bool = false
    @State private var apiKey: String = ""
    @State private var aiModel: String = SettingsStore.defaultAIModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section(header: Text("Hotkey")) {
                HStack(alignment: .center, spacing: 12) {
                    HotKeyRecorder(
                        displayText: currentHotKeyText(),
                        onKeyChange: applyHotKey
                    )
                    .frame(height: 28)

                    Spacer()

                    Toggle("Capture Cursor", isOn: $captureCursor)
                        .toggleStyle(.switch)
                }
            }

            Section(header: Text("OpenAI API Key")) {
                TextField("", text: $apiKey, prompt: Text("sk-proj-..."))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                HStack {
                    Text("Model")
                    Spacer()
                    AIModelPicker(selection: $aiModel, items: SettingsStore.availableAIModels)
                        .frame(width: 200)
                }
            }

            HStack {
                Spacer()
                Button("Apply") { applyChanges() }
                    .disabled(!hasChanges())
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear { loadFromDefaults() }
    }

    private func currentHotKeyText() -> String {
        let modifiers = formattedModifiers(
            command: hotKeyCommand,
            shift: hotKeyShift,
            option: hotKeyOption,
            control: hotKeyControl
        )
        let key = keyLabel(for: hotKeyCode)
        return modifiers + key
    }

    private func applyHotKey(code: UInt16, modifiers: NSEvent.ModifierFlags) {
        hotKeyCode = Int(code)
        hotKeyCommand = modifiers.contains(.command)
        hotKeyShift = modifiers.contains(.shift)
        hotKeyOption = modifiers.contains(.option)
        hotKeyControl = modifiers.contains(.control)
    }

    private func formattedModifiers(command: Bool, shift: Bool, option: Bool, control: Bool) -> String {
        var result = ""
        if control { result.append("⌃") }
        if option { result.append("⌥") }
        if shift { result.append("⇧") }
        if command { result.append("⌘") }
        return result
    }

    private func keyLabel(for code: Int) -> String {
        switch code {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Escape: return "Esc"
        case kVK_Delete: return "Delete"
        case kVK_Tab: return "Tab"
        default: return "Key"
        }
    }

    private func loadFromDefaults() {
        let defaults = UserDefaults.standard
        hotKeyCode = defaults.integer(forKey: SettingsStore.Key.hotKeyCode)
        hotKeyCommand = defaults.bool(forKey: SettingsStore.Key.hotKeyCommand)
        hotKeyShift = defaults.bool(forKey: SettingsStore.Key.hotKeyShift)
        hotKeyOption = defaults.bool(forKey: SettingsStore.Key.hotKeyOption)
        hotKeyControl = defaults.bool(forKey: SettingsStore.Key.hotKeyControl)
        captureCursor = defaults.bool(forKey: SettingsStore.Key.captureCursor)
        apiKey = defaults.string(forKey: SettingsStore.Key.apiKey) ?? ""
        aiModel = defaults.string(forKey: SettingsStore.Key.aiModel) ?? SettingsStore.defaultAIModel
    }

    private func hasChanges() -> Bool {
        let defaults = UserDefaults.standard
        if defaults.integer(forKey: SettingsStore.Key.hotKeyCode) != hotKeyCode { return true }
        if defaults.bool(forKey: SettingsStore.Key.hotKeyCommand) != hotKeyCommand { return true }
        if defaults.bool(forKey: SettingsStore.Key.hotKeyShift) != hotKeyShift { return true }
        if defaults.bool(forKey: SettingsStore.Key.hotKeyOption) != hotKeyOption { return true }
        if defaults.bool(forKey: SettingsStore.Key.hotKeyControl) != hotKeyControl { return true }
        if defaults.bool(forKey: SettingsStore.Key.captureCursor) != captureCursor { return true }
        if (defaults.string(forKey: SettingsStore.Key.apiKey) ?? "") != apiKey { return true }
        if (defaults.string(forKey: SettingsStore.Key.aiModel) ?? SettingsStore.defaultAIModel) != aiModel { return true }
        return false
    }

    private func applyChanges() {
        let defaults = UserDefaults.standard
        defaults.set(hotKeyCode, forKey: SettingsStore.Key.hotKeyCode)
        defaults.set(hotKeyCommand, forKey: SettingsStore.Key.hotKeyCommand)
        defaults.set(hotKeyShift, forKey: SettingsStore.Key.hotKeyShift)
        defaults.set(hotKeyOption, forKey: SettingsStore.Key.hotKeyOption)
        defaults.set(hotKeyControl, forKey: SettingsStore.Key.hotKeyControl)
        defaults.set(captureCursor, forKey: SettingsStore.Key.captureCursor)
        defaults.set(apiKey, forKey: SettingsStore.Key.apiKey)
        defaults.set(aiModel, forKey: SettingsStore.Key.aiModel)
        NotificationCenter.default.post(name: .hotkeyPreferencesDidChange, object: nil)
        loadFromDefaults()
        dismiss()
    }
}

struct HotKeyRecorder: NSViewRepresentable {
    let displayText: String
    let onKeyChange: (UInt16, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> HotKeyRecorderView {
        let view = HotKeyRecorderView()
        view.onKeyChange = onKeyChange
        view.placeholder = "Press shortcut"
        view.displayText = displayText
        return view
    }

    func updateNSView(_ nsView: HotKeyRecorderView, context: Context) {
        nsView.displayText = displayText
    }
}

struct AIModelPicker: NSViewRepresentable {
    @Binding var selection: String
    let items: [String]

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton()
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectionChanged(_:))
        button.addItems(withTitles: items)
        if let index = items.firstIndex(of: selection) {
            button.selectItem(at: index)
        }
        return button
    }

    func updateNSView(_ nsView: NSPopUpButton, context: Context) {
        nsView.removeAllItems()
        nsView.addItems(withTitles: items)
        if let index = items.firstIndex(of: selection) {
            nsView.selectItem(at: index)
        }
    }

    final class Coordinator: NSObject {
        @Binding private var selection: String

        init(selection: Binding<String>) {
            _selection = selection
        }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            selection = sender.titleOfSelectedItem ?? selection
        }
    }
}

final class HotKeyRecorderView: NSView {
    var onKeyChange: ((UInt16, NSEvent.ModifierFlags) -> Void)?
    var placeholder: String = ""
    var displayText: String = "" { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        NSColor(calibratedWhite: 0.15, alpha: 0.9).setFill()
        path.fill()
        NSColor(calibratedWhite: 1.0, alpha: 0.12).setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = displayText.isEmpty ? placeholder : displayText
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let rect = NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        onKeyChange?(event.keyCode, modifiers)
    }
}
