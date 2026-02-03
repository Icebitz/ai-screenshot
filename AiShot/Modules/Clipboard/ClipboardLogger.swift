import Foundation

struct ClipboardLogEntry {
    let timestamp: String
    let kind: String
    let content: String

    func formattedBlock() -> String {
        return "[\(kind)] \(timestamp)\n\(content)\n"
    }
}

final class ClipboardLogStore {
    static let shared = ClipboardLogStore()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "AiShot.ClipboardLogStore")
    private let logURL: URL

    private init() {
        AppPaths.ensureCacheStructure()
        if let logURL = AppPaths.clipboardLogURL() {
            self.logURL = logURL
            return
        }
        self.logURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("AiShot-data.log")
    }

    func ensureLogFile() {
        queue.async { [logURL, fileManager] in
            if fileManager.fileExists(atPath: logURL.path) {
                return
            }
            let directory = logURL.deletingLastPathComponent()
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            fileManager.createFile(atPath: logURL.path, contents: Data())
        }
    }

    func append(_ entry: ClipboardLogEntry) {
        queue.async { [logURL, fileManager] in
            let line = entry.formattedBlock()
            let data = Data(line.utf8)
            if !fileManager.fileExists(atPath: logURL.path) {
                fileManager.createFile(atPath: logURL.path, contents: data)
                AppPaths.copyLiveLogToTempIfNeeded()
                AppPaths.maintainTempCache()
                return
            }
            do {
                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
                AppPaths.copyLiveLogToTempIfNeeded()
                AppPaths.maintainTempCache()
            } catch {
                // Best-effort logging; ignore write errors.
            }
        }
    }
}
