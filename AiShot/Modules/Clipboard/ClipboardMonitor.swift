import AppKit
import Foundation

final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private let pollInterval: TimeInterval = 1.0

    private init() {}

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        ClipboardLogStore.shared.ensureLogFile()
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount
        let entry = makeClipboardLogEntry(from: pasteboard, source: "system")
        ClipboardLogStore.shared.append(entry)
    }
}
