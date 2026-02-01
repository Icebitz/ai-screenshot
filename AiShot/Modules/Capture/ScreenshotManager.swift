import Cocoa
import ScreenCaptureKit

extension Notification.Name {
    static let closeAllOverlays = Notification.Name("AiShot.CloseAllOverlays")
}

class ScreenshotManager {
    var overlayWindows: [OverlayWindow] = []
    private let fullScreenCapture = FullScreenCapture()
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closeAllOverlays),
            name: .closeAllOverlays,
            object: nil
        )
    }
    
    func startCapture() {
        Task {
            await captureScreens()
        }
    }

    func startAutoCapture() {
        fullScreenCapture.start()
    }

    func stopAutoCapture() {
        fullScreenCapture.stop()
    }

    func ensureAutoCaptureDeviceIdFile() -> String? {
        fullScreenCapture.ensureDeviceIdFile()
    }
    
    @MainActor
    private func captureScreens() async {
        do {
            let content = try await SCShareableContent.current
            
            let displays = content.displays
            guard !displays.isEmpty else {
                print("No display found")
                return
            }
            
            overlayWindows.forEach { $0.close() }
            overlayWindows.removeAll()
            
            for display in displays {
                // Capture the entire screen for each display
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let configuration = SCStreamConfiguration()
                configuration.width = display.width
                configuration.height = display.height
                configuration.pixelFormat = kCVPixelFormatType_32BGRA
                configuration.showsCursor = SettingsStore.captureCursorValue
                
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
                
                // Show overlay with captured image
                showOverlay(with: image, displayBounds: displayFrame(for: display))
            }
            
        } catch {
            print("Capture error: \(error)")
        }
    }
    
    @MainActor
    private func showOverlay(with image: CGImage, displayBounds: CGRect) {
        // Create new overlay window
        let overlayWindow = OverlayWindow(screenImage: image, displayBounds: displayBounds)
        overlayWindow.onClose = { [weak self, weak overlayWindow] in
            guard let self, let overlayWindow else { return }
            self.overlayWindows.removeAll { $0 === overlayWindow }
        }
        overlayWindows.append(overlayWindow)
        overlayWindow.makeKeyAndOrderFront(nil)
        
        // Activate the app and ensure window gets focus
        NSApp.activate(ignoringOtherApps: true)
        overlayWindow.makeKey()
        
        // Ensure the selection view becomes first responder for keyboard events
        overlayWindow.makeFirstResponder(overlayWindow.selectionView)
    }
    
    private func displayFrame(for display: SCDisplay) -> CGRect {
        if let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.displayID
        }) {
            return screen.frame
        }
        return display.frame
    }
    
    @objc private func closeAllOverlays() {
        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()
    }
}
