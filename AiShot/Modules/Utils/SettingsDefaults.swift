import Foundation
import Carbon

func registerSettingsDefaults() {
    UserDefaults.standard.register(defaults: [
        SettingsStore.Key.hotKeyCode: Int(kVK_ANSI_S),
        SettingsStore.Key.hotKeyCommand: true,
        SettingsStore.Key.hotKeyShift: true,
        SettingsStore.Key.hotKeyOption: false,
        SettingsStore.Key.hotKeyControl: false,
        SettingsStore.Key.captureCursor: false,
        SettingsStore.Key.aiModel: SettingsStore.defaultAIModel
    ])
}
