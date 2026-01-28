import Foundation
import Carbon

extension Notification.Name {
    static let hotkeyPreferencesDidChange = Notification.Name("ScreenshotApp.HotkeyPreferencesDidChange")
}

enum SettingsStore {
    enum Key {
        static let hotKeyCode = "hotkey.code"
        static let hotKeyCommand = "hotkey.modifier.command"
        static let hotKeyShift = "hotkey.modifier.shift"
        static let hotKeyOption = "hotkey.modifier.option"
        static let hotKeyControl = "hotkey.modifier.control"
        static let saveDirectoryPath = "save.directory.path"
        static let apiKey = "ai.api.key"
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.hotKeyCode: Int(kVK_ANSI_0),
            Key.hotKeyCommand: true,
            Key.hotKeyShift: true,
            Key.hotKeyOption: false,
            Key.hotKeyControl: false
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
}
