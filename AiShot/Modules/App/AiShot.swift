import SwiftUI
import ScreenCaptureKit
import Carbon
import ServiceManagement

@main
struct AiShot: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var screenshotManager: ScreenshotManager?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination("Keep menu bar app alive")
        SettingsStore.registerDefaults()
        registerLaunchAtLogin()

        if let appIcon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = appIcon
        }
        
        // Request screen recording permission
        requestScreenRecordingPermission()
        
        // Setup menu bar
        setupMenuBar()
        
        // Initialize screenshot manager
        screenshotManager = ScreenshotManager()
        registerGlobalHotKey()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshHotKey),
            name: .hotkeyPreferencesDidChange,
            object: nil
        )
    }

    private func registerLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
            } catch {
                print("Failed to register launch at login: \(error)")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ProcessInfo.processInfo.enableAutomaticTermination("Keep menu bar app alive")
        unregisterGlobalHotKey()
    }
    
    func requestScreenRecordingPermission() {
        Task {
            do {
                // This will prompt for screen recording permission if not granted
                let content = try await SCShareableContent.current
                _ = content.displays
            } catch {
                print("Screen recording permission error: \(error)")
//                DispatchQueue.main.async {
//                    self.showPermissionAlert()
//                }
            }
        }
    }
    
    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Please grant screen recording permission in System Settings > Privacy & Security > Screen Recording"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // button.image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "Screenshot")
            let image = NSImage(named: "MenuIcon")
            image?.isTemplate = true
            button.image = image
        }
        
        let menu = NSMenu()
        
        let screenshotItem = NSMenuItem(title: "Take Screenshot...", action: #selector(takeScreenshot), keyEquivalent: "0")
        screenshotItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(screenshotItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: ""))
        
        statusItem?.menu = menu
    }
    
    @objc func takeScreenshot() {
        screenshotManager?.startCapture()
    }

    @objc func openSettings() {
        SettingsWindowController.shared.show()
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func registerGlobalHotKey() {
        unregisterGlobalHotKey()
        let hotKeyId = EventHotKeyID(signature: OSType(UInt32(truncatingIfNeeded: ("SSAP" as NSString).hash)), id: 1)
        let modifiers: UInt32 = SettingsStore.hotKeyModifiers
        let keyCode: UInt32 = SettingsStore.hotKeyCode
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyId, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else {
            print("Failed to register hotkey: \(status)")
            return
        }

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                delegate.takeScreenshot()
            }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventSpec, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &hotKeyHandler)
    }

    private func unregisterGlobalHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let hotKeyHandler {
            RemoveEventHandler(hotKeyHandler)
            self.hotKeyHandler = nil
        }
    }

    @objc private func refreshHotKey() {
        registerGlobalHotKey()
    }
}
