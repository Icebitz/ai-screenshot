import AppKit
import Foundation
import UniformTypeIdentifiers

struct ClipboardLogEntry {
    let timestamp: String
    let source: String
    let types: [String]
    let stringPreview: String?
    let fileURLs: [String]?
    let hasImage: Bool

    static func fromPasteboard(_ pasteboard: NSPasteboard, source: String) -> ClipboardLogEntry {
        let types = pasteboard.types?.map { $0.rawValue } ?? []
        let stringPreview = makePreview(pasteboard.string(forType: .string))
        let fileURLs = makeFileURLs(pasteboard)
        let hasImage = pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) ||
            pasteboard.canReadItem(withDataConformingToTypes: [
                UTType.png.identifier,
                UTType.jpeg.identifier,
                UTType.tiff.identifier
            ])
        return ClipboardLogEntry(
            timestamp: timestampNow(),
            source: source,
            types: types,
            stringPreview: stringPreview,
            fileURLs: fileURLs,
            hasImage: hasImage
        )
    }

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

    private static func timestampNow() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private static func makePreview(_ text: String?, limit: Int = 200) -> String? {
        guard let text, !text.isEmpty else { return nil }
        let singleLine = text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        if singleLine.count <= limit {
            return singleLine
        }
        let index = singleLine.index(singleLine.startIndex, offsetBy: limit)
        return String(singleLine[..<index]) + "…"
    }

    private static func makeFileURLs(_ pasteboard: NSPasteboard) -> [String]? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        guard let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              !objects.isEmpty else { return nil }
        return objects.map { $0.path }
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
