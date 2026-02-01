import AppKit
import Foundation
import UniformTypeIdentifiers

func makeClipboardLogEntry(from pasteboard: NSPasteboard, source _: String) -> ClipboardLogEntry {
    let timestamp = clipboardTimestampNow()
    if let text = pasteboard.string(forType: .string), !text.isEmpty {
        return ClipboardLogEntry(timestamp: timestamp, kind: "TEXT", content: text)
    }
    if let fileURLs = clipboardFileURLs(from: pasteboard), !fileURLs.isEmpty {
        return ClipboardLogEntry(timestamp: timestamp, kind: "FILES", content: fileURLs.joined(separator: "\n"))
    }
    let hasImage = pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) ||
        pasteboard.canReadItem(withDataConformingToTypes: [
            UTType.png.identifier,
            UTType.jpeg.identifier,
            UTType.tiff.identifier
        ])
    if hasImage {
        if let filename = saveClipboardImage(from: pasteboard, timestamp: timestamp) {
            return ClipboardLogEntry(timestamp: timestamp, kind: "IMAGE", content: filename)
        }
        return ClipboardLogEntry(timestamp: timestamp, kind: "IMAGE", content: "Image")
    }
    let types = pasteboard.types?.map { $0.rawValue }.joined(separator: ", ") ?? "unknown"
    return ClipboardLogEntry(timestamp: timestamp, kind: "UNKNOWN", content: "Pasteboard types: \(types)")
}

private func clipboardTimestampNow() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date())
}


private func clipboardFileURLs(from pasteboard: NSPasteboard) -> [String]? {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [
        .urlReadingFileURLsOnly: true
    ]
    guard let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
          !objects.isEmpty else { return nil }
    return objects.map { $0.path }
}

private func saveClipboardImage(from pasteboard: NSPasteboard, timestamp: String) -> String? {
    guard let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else {
        return nil
    }
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return nil
    }
    let fileManager = FileManager.default
    AppPaths.ensureCacheStructure()
    let imagesDirectory = (AppPaths.liveClipDirectoryURL()
        ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true))
    try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    let filename = "clipboard-\(timestamp).png"
    let safeFilename = filename.replacingOccurrences(of: ":", with: "-")
    let targetURL = imagesDirectory.appendingPathComponent(safeFilename)
    do {
        try pngData.write(to: targetURL, options: .atomic)
        return safeFilename
    } catch {
        return nil
    }
}
