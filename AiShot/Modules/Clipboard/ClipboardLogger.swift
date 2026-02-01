import Foundation

struct ClipboardLogEntry {
    let timestamp: String
    let source: String
    let types: [String]
    let stringPreview: String?
    let fileURLs: [String]?
    let hasImage: Bool

    func jsonLine() -> String {
        var payload: [String: Any] = [
            "timestamp": timestamp,
            "source": source,
            "types": types,
            "hasImage": hasImage
        ]
        if let stringPreview {
            payload["stringPreview"] = stringPreview
        }
        if let fileURLs {
            payload["fileURLs"] = fileURLs
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"timestamp\":\"\(timestamp)\",\"source\":\"\(source)\",\"types\":[],\"hasImage\":\(hasImage)}"
        }
        return json
    }
}

final class ClipboardLogStore {
    static let shared = ClipboardLogStore()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "AiShot.ClipboardLogStore")
    private let logURL: URL

    private init() {
        if let directory = AppPaths.baseDirectoryURL() {
            logURL = directory.appendingPathComponent("clipboard.log")
            return
        }
        logURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("AiShot-clipboard.log")
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
            let line = entry.jsonLine() + "\n"
            let data = Data(line.utf8)
            if !fileManager.fileExists(atPath: logURL.path) {
                fileManager.createFile(atPath: logURL.path, contents: data)
                return
            }
            do {
                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } catch {
                // Best-effort logging; ignore write errors.
            }
        }
    }
}
