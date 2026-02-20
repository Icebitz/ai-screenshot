import SwiftUI
import Combine
import Carbon
import AppKit

// MARK: - Model

enum ImageModel: String, CaseIterable, Identifiable {
    case gptImage15 = "gpt-image-1.5"
    case gptImage1 = "gpt-image-1"
    case gptImage1Mini = "gpt-image-1-mini"

    var id: String { rawValue }
    var label: String { rawValue }
}

// MARK: - View Model

final class SettingsViewModel: ObservableObject {
    @Published var hotKeyCode: Int = Int(kVK_ANSI_S)
    @Published var hotKeyCommand: Bool = true
    @Published var hotKeyShift: Bool = true
    @Published var hotKeyOption: Bool = false
    @Published var hotKeyControl: Bool = true

    @Published var captureCursor: Bool = false
    @Published var apiKey: String = ""
    @Published var model: ImageModel = .gptImage1Mini

    @Published private(set) var isDirty: Bool = false

    var hotkeyDisplay: String {
        formattedModifiers() + keyLabel(for: hotKeyCode)
    }

    private var snapshot: Snapshot

    struct Snapshot: Equatable {
        var hotKeyCode: Int
        var hotKeyCommand: Bool
        var hotKeyShift: Bool
        var hotKeyOption: Bool
        var hotKeyControl: Bool
        var captureCursor: Bool
        var apiKey: String
        var model: ImageModel
    }

    init() {
        let defaults = UserDefaults.standard

        let code = defaults.integer(forKey: SettingsStore.Key.hotKeyCode)
        let cmd = defaults.bool(forKey: SettingsStore.Key.hotKeyCommand)
        let shift = defaults.bool(forKey: SettingsStore.Key.hotKeyShift)
        let opt = defaults.bool(forKey: SettingsStore.Key.hotKeyOption)
        let ctrl = defaults.bool(forKey: SettingsStore.Key.hotKeyControl)
        let cursor = defaults.bool(forKey: SettingsStore.Key.captureCursor)
        let key = defaults.string(forKey: SettingsStore.Key.apiKey) ?? ""
        let modelRaw = defaults.string(forKey: SettingsStore.Key.aiModel) ?? SettingsStore.defaultAIModel
        let m = ImageModel(rawValue: modelRaw) ?? .gptImage1Mini

        let codeVal = code != 0 ? code : Int(kVK_ANSI_S)

        self.hotKeyCode = codeVal
        self.hotKeyCommand = cmd
        self.hotKeyShift = shift
        self.hotKeyOption = opt
        self.hotKeyControl = ctrl

        self.captureCursor = cursor
        self.apiKey = key
        self.model = m

        self.snapshot = Snapshot(
            hotKeyCode: codeVal,
            hotKeyCommand: cmd,
            hotKeyShift: shift,
            hotKeyOption: opt,
            hotKeyControl: ctrl,
            captureCursor: cursor,
            apiKey: key,
            model: m
        )

        recomputeDirty()
    }

    func recomputeDirty() {
        let current = Snapshot(
            hotKeyCode: hotKeyCode,
            hotKeyCommand: hotKeyCommand,
            hotKeyShift: hotKeyShift,
            hotKeyOption: hotKeyOption,
            hotKeyControl: hotKeyControl,
            captureCursor: captureCursor,
            apiKey: apiKey,
            model: model
        )
        isDirty = (current != snapshot)
    }

    func apply() {
        let defaults = UserDefaults.standard
        defaults.set(hotKeyCode, forKey: SettingsStore.Key.hotKeyCode)
        defaults.set(hotKeyCommand, forKey: SettingsStore.Key.hotKeyCommand)
        defaults.set(hotKeyShift, forKey: SettingsStore.Key.hotKeyShift)
        defaults.set(hotKeyOption, forKey: SettingsStore.Key.hotKeyOption)
        defaults.set(hotKeyControl, forKey: SettingsStore.Key.hotKeyControl)

        defaults.set(captureCursor, forKey: SettingsStore.Key.captureCursor)
        defaults.set(apiKey, forKey: SettingsStore.Key.apiKey)
        defaults.set(model.rawValue, forKey: SettingsStore.Key.aiModel)

        NotificationCenter.default.post(name: .hotkeyPreferencesDidChange, object: nil)

        snapshot = Snapshot(
            hotKeyCode: hotKeyCode,
            hotKeyCommand: hotKeyCommand,
            hotKeyShift: hotKeyShift,
            hotKeyOption: hotKeyOption,
            hotKeyControl: hotKeyControl,
            captureCursor: captureCursor,
            apiKey: apiKey,
            model: model
        )
        recomputeDirty()
    }

    func cancelRevert() {
        hotKeyCode = snapshot.hotKeyCode
        hotKeyCommand = snapshot.hotKeyCommand
        hotKeyShift = snapshot.hotKeyShift
        hotKeyOption = snapshot.hotKeyOption
        hotKeyControl = snapshot.hotKeyControl

        captureCursor = snapshot.captureCursor
        apiKey = snapshot.apiKey
        model = snapshot.model

        recomputeDirty()
    }

    func applyHotKey(code: UInt16, modifiers: NSEvent.ModifierFlags) {
        hotKeyCode = Int(code)
        hotKeyCommand = modifiers.contains(.command)
        hotKeyShift = modifiers.contains(.shift)
        hotKeyOption = modifiers.contains(.option)
        hotKeyControl = modifiers.contains(.control)
        recomputeDirty()
    }

    var apiKeyLooksValid: Bool {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("sk-") && trimmed.count >= 20
    }

    private func formattedModifiers() -> String {
        var result = ""
        if hotKeyControl { result.append("⌃") }
        if hotKeyOption { result.append("⌥") }
        if hotKeyShift { result.append("⇧") }
        if hotKeyCommand { result.append("⌘") }
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
}

// MARK: - View

struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showApiKey: Bool = false
    @State private var showHotKeyRecorder: Bool = false
    @State private var highlightHotkeyPill: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 12) {
                generalSection
                openAISection
            }

            Divider()

            footerButtons
        }
        .padding(20)
        .frame(width: 420)
        .onChange(of: vm.hotKeyCode) { vm.recomputeDirty() }
        .onChange(of: vm.hotKeyCommand) { vm.recomputeDirty() }
        .onChange(of: vm.hotKeyShift) { vm.recomputeDirty() }
        .onChange(of: vm.hotKeyOption) { vm.recomputeDirty() }
        .onChange(of: vm.hotKeyControl) { vm.recomputeDirty() }
        .onChange(of: vm.captureCursor) { vm.recomputeDirty() }
        .onChange(of: vm.apiKey) { vm.recomputeDirty() }
        .onChange(of: vm.model) { vm.recomputeDirty() }
        .sheet(isPresented: $showHotKeyRecorder) {
            hotKeyRecorderSheet
        }
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                highlightHotkeyPill = false
            }
        }
    }

    private var generalSection: some View {
        SettingsSection(title: "General") {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    Text("Hotkey")
                        .frame(width: 90, alignment: .leading)
                        .font(.system(size: 12))

                    HotkeyPill(text: (vm.hotkeyDisplay.isEmpty || vm.hotkeyDisplay == "Key") ? "None" : vm.hotkeyDisplay, highlighted: highlightHotkeyPill)
                        .frame(maxWidth: .infinity)

                    Button("Change…") {
                        showHotKeyRecorder = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.vertical, 10)

                Divider()

                HStack(alignment: .center, spacing: 10) {
                    Text("Capture Cursor")
                        .frame(width: 90, alignment: .leading)
                        .font(.system(size: 12))

                    Spacer(minLength: 0)

                    Toggle("", isOn: $vm.captureCursor)
                        .labelsHidden()
                }
                .padding(.vertical, 10)
            }
        }
    }

    private var openAISection: some View {
        SettingsSection(title: "OpenAI") {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    Text("API Key")
                        .frame(width: 90, alignment: .leading)
                        .font(.system(size: 12))
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Group {
                                if showApiKey {
                                    TextField("sk-…", text: $vm.apiKey)
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    SecureField("sk-…", text: $vm.apiKey)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .font(.system(size: 12, design: .monospaced))
                            .frame(maxWidth: .infinity)

                            Button {
                                showApiKey.toggle()
                            } label: {
                                Image(systemName: showApiKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .help(showApiKey ? "Hide API key" : "Show API key")
                        }

                        Text("Used for AI image editing requests.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 10)

                Divider()

                HStack(alignment: .top, spacing: 8) {
                    Text("Model")
                        .frame(width: 70, alignment: .leading)
                        .font(.system(size: 12))
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 4) {
                        Picker("", selection: $vm.model) {
                            ForEach(ImageModel.allCases) { m in
                                Text(m.label).tag(m)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .controlSize(.large)

                        Text("Image editing model for screenshot processing.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }

    private var footerButtons: some View {
        HStack {
            Spacer()

            Button("Cancel") {
                vm.cancelRevert()
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .controlSize(.large)

            Button("Apply") {
                vm.apply()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!vm.isDirty)
        }
    }

    private var hotKeyRecorderSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Press a key combination")
                .font(.system(size: 15, weight: .semibold))

            HotKeyRecorder(
                displayText: vm.hotkeyDisplay,
                onKeyChange: { code, modifiers in
                    vm.applyHotKey(code: code, modifiers: modifiers)
                    showHotKeyRecorder = false
                }
            )
            .frame(height: 32)

            HStack {
                Spacer()
                Button("Cancel") { showHotKeyRecorder = false }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
            }
        }
        .padding(20)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

// MARK: - Hotkey Pill (light macOS style)

struct HotkeyPill: View {
    let text: String
    var highlighted: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(NSColor.quaternaryLabelColor).opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        highlighted ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.35),
                        lineWidth: highlighted ? 2 : 1
                    )
            )
    }
}

// MARK: - Reusable Section Card

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
    }
}

// MARK: - HotKeyRecorder (NSViewRepresentable)

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

final class HotKeyRecorderView: NSView {
    var onKeyChange: ((UInt16, NSEvent.ModifierFlags) -> Void)?
    var placeholder: String = ""
    var displayText: String = "" { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)

        NSColor.quaternaryLabelColor.withAlphaComponent(0.10).setFill()
        path.fill()

        NSColor.separatorColor.withAlphaComponent(0.35).setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = displayText.isEmpty ? placeholder : displayText
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]

        let size = (text as NSString).size(withAttributes: attributes)
        let drawRect = NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        (text as NSString).draw(in: drawRect, withAttributes: attributes)
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

#Preview {
    SettingsView()
        .frame(width: 640, height: 520)
}
