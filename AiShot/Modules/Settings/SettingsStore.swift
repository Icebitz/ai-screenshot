import Foundation
import Carbon

extension Notification.Name {
    static let hotkeyPreferencesDidChange = Notification.Name("AiShot.HotkeyPreferencesDidChange")
}

enum SettingsStore {
    enum Key {
        static let hotKeyCode = "hotkey.code"
        static let hotKeyCommand = "hotkey.modifier.command"
        static let hotKeyShift = "hotkey.modifier.shift"
        static let hotKeyOption = "hotkey.modifier.option"
        static let hotKeyControl = "hotkey.modifier.control"
        static let captureCursor = "capture.cursor"
        static let saveDirectoryPath = "save.directory.path"
        static let apiKey = "ai.api.key"
        static let aiModel = "ai.model"
    }

    static let availableAIModels = [
        "gpt-image-1.5",
        "gpt-image-1",
        "gpt-image-1-mini"
    ]
    static let defaultAIModel = "gpt-image-1-mini"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.hotKeyCode: Int(kVK_ANSI_S),
            Key.hotKeyCommand: true,
            Key.hotKeyShift: true,
            Key.hotKeyOption: false,
            Key.hotKeyControl: false,
            Key.captureCursor: false,
            Key.aiModel: defaultAIModel
        ])
    }

    static var hotKeyCode: UInt32 {
        UInt32(UserDefaults.standard.integer(forKey: Key.hotKeyCode))
    }

    static var hotKeyModifiers: UInt32 {
        var modifiers: UInt32 = 0
        if UserDefaults.standard.bool(forKey: Key.hotKeyCommand) { modifiers |= UInt32(cmdKey) }
        if UserDefaults.standard.bool(forKey: Key.hotKeyShift) { modifiers |= UInt32(shiftKey) }
        if UserDefaults.standard.bool(forKey: Key.hotKeyOption) { modifiers |= UInt32(optionKey) }
        if UserDefaults.standard.bool(forKey: Key.hotKeyControl) { modifiers |= UInt32(controlKey) }
        return modifiers
    }

    static var saveDirectoryURL: URL? {
        guard let path = UserDefaults.standard.string(forKey: Key.saveDirectoryPath),
              !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static var captureCursorValue: Bool {
        UserDefaults.standard.bool(forKey: Key.captureCursor)
    }

    static var apiKeyValue: String {
        UserDefaults.standard.string(forKey: Key.apiKey) ?? ""
    }

    static var aiModelValue: String {
        UserDefaults.standard.string(forKey: Key.aiModel) ?? defaultAIModel
    }

}
