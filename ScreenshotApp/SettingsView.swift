import SwiftUI
import Carbon

struct SettingsView: View {
    @AppStorage(SettingsStore.Key.hotKeyCode) private var hotKeyCode: Int = Int(kVK_ANSI_0)
    @AppStorage(SettingsStore.Key.hotKeyCommand) private var hotKeyCommand: Bool = true
    @AppStorage(SettingsStore.Key.hotKeyShift) private var hotKeyShift: Bool = true
    @AppStorage(SettingsStore.Key.hotKeyOption) private var hotKeyOption: Bool = false
    @AppStorage(SettingsStore.Key.hotKeyControl) private var hotKeyControl: Bool = false
    @AppStorage(SettingsStore.Key.saveDirectoryPath) private var saveDirectoryPath: String = ""
    @AppStorage(SettingsStore.Key.apiKey) private var apiKey: String = ""

    private let keyOptions: [HotKeyOption] = HotKeyOption.defaults

    var body: some View {
        Form {
            Section(header: Text("Hotkey")) {
                Picker("Key", selection: $hotKeyCode) {
                    ForEach(keyOptions) { option in
                        Text(option.label).tag(option.code)
                    }
                }
                .onChange(of: hotKeyCode) { _ in notifyHotkeyChange() }

                HStack {
                    Toggle("Command", isOn: $hotKeyCommand)
                    Toggle("Shift", isOn: $hotKeyShift)
                    Toggle("Option", isOn: $hotKeyOption)
                    Toggle("Control", isOn: $hotKeyControl)
                }
                .onChange(of: hotKeyCommand) { _ in notifyHotkeyChange() }
                .onChange(of: hotKeyShift) { _ in notifyHotkeyChange() }
                .onChange(of: hotKeyOption) { _ in notifyHotkeyChange() }
                .onChange(of: hotKeyControl) { _ in notifyHotkeyChange() }
            }

            Section(header: Text("AI Mode")) {
                SecureField("API Key", text: $apiKey)
            }

            Section(header: Text("Saving")) {
                HStack {
                    TextField("Save path", text: $saveDirectoryPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Choose…") { chooseSaveDirectory() }
                }
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Save Folder"
        if panel.runModal() == .OK, let url = panel.url {
            saveDirectoryPath = url.path
        }
    }

    private func notifyHotkeyChange() {
        NotificationCenter.default.post(name: .hotkeyPreferencesDidChange, object: nil)
    }
}

struct HotKeyOption: Identifiable {
    let id = UUID()
    let label: String
    let code: Int

    static let defaults: [HotKeyOption] = [
        HotKeyOption(label: "0", code: Int(kVK_ANSI_0)),
        HotKeyOption(label: "1", code: Int(kVK_ANSI_1)),
        HotKeyOption(label: "2", code: Int(kVK_ANSI_2)),
        HotKeyOption(label: "3", code: Int(kVK_ANSI_3)),
        HotKeyOption(label: "4", code: Int(kVK_ANSI_4)),
        HotKeyOption(label: "5", code: Int(kVK_ANSI_5)),
        HotKeyOption(label: "6", code: Int(kVK_ANSI_6)),
        HotKeyOption(label: "7", code: Int(kVK_ANSI_7)),
        HotKeyOption(label: "8", code: Int(kVK_ANSI_8)),
        HotKeyOption(label: "9", code: Int(kVK_ANSI_9)),
        HotKeyOption(label: "A", code: Int(kVK_ANSI_A)),
        HotKeyOption(label: "B", code: Int(kVK_ANSI_B)),
        HotKeyOption(label: "C", code: Int(kVK_ANSI_C)),
        HotKeyOption(label: "D", code: Int(kVK_ANSI_D)),
        HotKeyOption(label: "E", code: Int(kVK_ANSI_E)),
        HotKeyOption(label: "F", code: Int(kVK_ANSI_F)),
        HotKeyOption(label: "G", code: Int(kVK_ANSI_G)),
        HotKeyOption(label: "H", code: Int(kVK_ANSI_H)),
        HotKeyOption(label: "I", code: Int(kVK_ANSI_I)),
        HotKeyOption(label: "J", code: Int(kVK_ANSI_J)),
        HotKeyOption(label: "K", code: Int(kVK_ANSI_K)),
        HotKeyOption(label: "L", code: Int(kVK_ANSI_L)),
        HotKeyOption(label: "M", code: Int(kVK_ANSI_M)),
        HotKeyOption(label: "N", code: Int(kVK_ANSI_N)),
        HotKeyOption(label: "O", code: Int(kVK_ANSI_O)),
        HotKeyOption(label: "P", code: Int(kVK_ANSI_P)),
        HotKeyOption(label: "Q", code: Int(kVK_ANSI_Q)),
        HotKeyOption(label: "R", code: Int(kVK_ANSI_R)),
        HotKeyOption(label: "S", code: Int(kVK_ANSI_S)),
        HotKeyOption(label: "T", code: Int(kVK_ANSI_T)),
        HotKeyOption(label: "U", code: Int(kVK_ANSI_U)),
        HotKeyOption(label: "V", code: Int(kVK_ANSI_V)),
        HotKeyOption(label: "W", code: Int(kVK_ANSI_W)),
        HotKeyOption(label: "X", code: Int(kVK_ANSI_X)),
        HotKeyOption(label: "Y", code: Int(kVK_ANSI_Y)),
        HotKeyOption(label: "Z", code: Int(kVK_ANSI_Z))
    ]
}
