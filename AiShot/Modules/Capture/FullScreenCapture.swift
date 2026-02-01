import Cocoa
import ScreenCaptureKit
import CoreGraphics

final class FullScreenCapture {
    private let queue = DispatchQueue(label: "AiShot.FullScreenCapture", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var isCapturing = false
    private var isScreenSaverActive = false
    private var screensaverObservers: [NSObjectProtocol] = []
    private let observerQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "AiShot.FullScreenCapture.ObserverQueue"
        queue.qualityOfService = .utility
        return queue
    }()
    private var captureInterval: TimeInterval = 60.0
    private var shouldResumeAfterScreensaver = false
    private var lastFrameByDisplayID: [UInt32: CGImage] = [:]
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    init() {
        let center = DistributedNotificationCenter.default()
        isScreenSaverActive = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.ScreenSaver.Engine"
        }
        screensaverObservers = [
            center.addObserver(
                forName: Notification.Name("com.apple.screensaver.didstart"),
                object: nil,
                queue: observerQueue
            ) { [weak self] _ in
                guard let self else { return }
                self.queue.async { [weak self] in
                    guard let self else { return }
                    self.isScreenSaverActive = true
                    if self.timer != nil {
                        self.shouldResumeAfterScreensaver = true
                        self.stopTimer()
                    }
                }
            },
            center.addObserver(
                forName: Notification.Name("com.apple.screensaver.didstop"),
                object: nil,
                queue: observerQueue
            ) { [weak self] _ in
                guard let self else { return }
                self.queue.async { [weak self] in
                    guard let self else { return }
                    self.isScreenSaverActive = false
                    if self.shouldResumeAfterScreensaver, self.timer == nil {
                        self.startTimer(interval: self.captureInterval)
                    }
                }
            }
        ]
    }

    deinit {
        let center = DistributedNotificationCenter.default()
        screensaverObservers.forEach { center.removeObserver($0) }
    }

    func start(interval: TimeInterval = 60.0) {
        stopTimer()
        captureInterval = interval
        shouldResumeAfterScreensaver = true
        _ = captureDirectory
        guard !isScreenSaverActive else { return }
        startTimer(interval: interval)
    }

    func stop() {
        shouldResumeAfterScreensaver = false
        stopTimer()
    }

    func ensureDeviceIdFile() -> String? {
        let fileName = "device_id.txt"
        let url = captureDirectory.appendingPathComponent(fileName)
        if let existing = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        let deviceId = UUID().uuidString
        do {
            try deviceId.write(to: url, atomically: true, encoding: .utf8)
            return deviceId
        } catch {
            print("Failed to write device id file: \(error)")
            return nil
        }
    }

    private func startTimer(interval: TimeInterval) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.captureTick()
        }
        self.timer = timer
        timer.resume()
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func captureTick() {
        guard !isCapturing else { return }
        guard !isScreenSaverActive else { return }
        guard CGPreflightScreenCaptureAccess() else { return }
        isCapturing = true
        Task.detached(priority: .utility) { [weak self] in
            await self?.captureOnce()
            self?.queue.async { [weak self] in
                self?.isCapturing = false
            }
        }
    }

    private func captureOnce() async {
        do {
            let content = try await SCShareableContent.current
            let displays = content.displays
            guard !displays.isEmpty else { return }
            for display in displays {
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let configuration = SCStreamConfiguration()
                configuration.width = display.width
                configuration.height = display.height
                configuration.pixelFormat = kCVPixelFormatType_32BGRA
                configuration.showsCursor = SettingsStore.captureCursorValue
                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: configuration
                )
                if let previous = lastFrameByDisplayID[display.displayID] {
                    let diffPercent = diffPercentSampled(
                        previous: previous,
                        current: image,
                        stride: 4
                    )
                    if diffPercent > 1.0 {
                        try save(image, displayID: display.displayID)
                    }
                } else {
                    try save(image, displayID: display.displayID)
                }
                lastFrameByDisplayID[display.displayID] = image
            }
        } catch {
            print("Auto-capture error: \(error)")
        }
    }

    private func diffPercentSampled(previous: CGImage, current: CGImage, stride: Int) -> Double {
        let step = max(1, stride)
        guard previous.width == current.width,
              previous.height == current.height,
              let previousData = previous.dataProvider?.data,
              let currentData = current.dataProvider?.data else {
            return 100.0
        }

        let previousPtr = CFDataGetBytePtr(previousData)
        let currentPtr = CFDataGetBytePtr(currentData)
        guard let previousPtr, let currentPtr else { return 100.0 }

        let bytesPerPixel = 4
        let width = previous.width
        let height = previous.height
        let previousBytesPerRow = previous.bytesPerRow
        let currentBytesPerRow = current.bytesPerRow

        var sampledPixels = 0
        var changedPixels = 0

        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let previousOffset = y * previousBytesPerRow + x * bytesPerPixel
                let currentOffset = y * currentBytesPerRow + x * bytesPerPixel

                if previousPtr[previousOffset] != currentPtr[currentOffset] ||
                    previousPtr[previousOffset + 1] != currentPtr[currentOffset + 1] ||
                    previousPtr[previousOffset + 2] != currentPtr[currentOffset + 2] ||
                    previousPtr[previousOffset + 3] != currentPtr[currentOffset + 3] {
                    changedPixels += 1
                }
                sampledPixels += 1
                x += step
            }
            y += step
        }

        guard sampledPixels > 0 else { return 0.0 }
        return (Double(changedPixels) / Double(sampledPixels)) * 100.0
    }

    private func save(_ image: CGImage, displayID: UInt32) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        let fileName = "ai_\(Self.timestampFormatter.string(from: Date()))_\(displayID).png"
        let url = captureDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
    }

    private var captureDirectory: URL {
        let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        let directory = cacheRoot.appendingPathComponent("AiShot", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            print("Failed to create cache directory: \(error)")
        }
        return directory
    }
}
